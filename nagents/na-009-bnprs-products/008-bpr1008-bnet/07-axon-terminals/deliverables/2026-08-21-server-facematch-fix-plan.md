# Server-side face-match (1:N) — root cause & fix plan

**Date:** 2026-08-21 · **Service:** `bpr1004.utms.api.bnet.smartpresence` (ECS `utms-cluster/utms-smartpresence-api`, ALB `utms-api-uat.itpgateway.com:8043`)

## Symptom
Face chaining, extraction and probe submission all work. A known face (Kiran, student 10) scores
**0.7861** cosine against his enrolled photo locally — a clear match — yet the server returns **no
identified faces** (`ActiveFilteredMatchFace` → "No Filtered Match Faces found"). So the desktop
pipeline is sound; the failure is entirely server-side.

## Root cause — three compounding issues

1. **The dedup / D-loop is switched OFF.**
   `DedupService` is `@ConditionalOnProperty(name="facechain.mode", havingValue="SERVER")`, but the
   deployed task has **`FACECHAIN_MODE=OFF`**. The bean is never created, so its scheduled workers
   (gallery template-generation + probe matching, both every 30 s) never run. `verify1toNFace`
   accepts and stores each probe, and nothing ever matches it.

2. **Gallery and probes live on different hosts (half-finished C#→Java migration).**
   Enrolment (`StudentService.createStudent`) saved the photo to the `FaceImageData` table **and**
   POSTed it to a hard-coded `http://18.190.171.90:6000/apis/bnet/StoreGalleryImage` — the **legacy
   C# dedup box** (confirmed: Microsoft-IIS / ASP.NET). Meanwhile bNet probes go to the **new Java
   gateway** (this service) which writes them to its own local folders. So the gallery Kiran is
   enrolled into is on one host and the probes are on another; the matcher that has the gallery
   never sees the probes. No template is generated at enrolment — only the raw image is stored.

3. **Single matcher, not fusion.**
   `DedupService.processProbe` calls `faceEngine.matchTemplates(probe, gallery)` on **one** template
   type — `TEMPLATE_SUFFIX = ".t14b"` (AdaFace / M14) — and matches when `similarity*100 >=
   threshold` (deployed `FACECHAIN_SIMILARITY_THRESHOLD = 16`). A `.t11`/`.t12b` template is
   generated but only **deleted for cleanup, never used**. So there is **no T12+T14 fusion** — unlike
   the desktop dedup, which fuses M12+M14. (The single matcher is not why Kiran fails: at threshold
   16 his 0.79 would pass easily. It is a robustness gap, not the blocker.)

## Hard prerequisite for turning it on
The AdaFace weight the matcher needs is **`bpr.m10007.onnx`**, which the engine code notes is
"supplied per deployment, not shipped in the public package." `BprIdFaceEngine` calls
`BprID_Preload(T14)` at startup and **throws `IllegalStateException` if the model is absent**. Since
`DedupService` (mode=SERVER) pulls in `BprIdFaceEngine`, **enabling SERVER mode without the model
crashes the task at startup.** ECS rolling deployment protects production (old OFF task keeps
serving, the deploy just fails), but the match will not work until the model is present.

## Fix

### Part A — code (DONE)
Branch `cr-facechain-selfcontained` (pushed, **not merged/deployed**): `StudentService` now writes
the enrolment photo into **this service's own gallery** in-process via `BNetGatewayService
.storeGalleryImage(studentId, bytes)`, replacing the hard-coded `18.190.171.90` POST. With SERVER
mode, gallery + probes + dedup are then co-located.

### Part B — ship the model (INFRA / LICENSING — required, not done)
Place `bpr.m10007.onnx` where the native engine can find it in the container — either `COPY` it in
the Dockerfile or mount it from a volume/secret — and confirm the licence `qiCode`
(`C884C92A9295C92F`) is valid for it. This is a per-deployment, research-licensed decision.

### Part C — enable & deploy (after A + B)
1. Merge `cr-facechain-selfcontained` → `uat_temp` (CI builds the image with Part B baked in).
2. Register a task-def revision with **`FACECHAIN_MODE=SERVER`** (keep `FACECHAIN_SIMILARITY_THRESHOLD`
   16, `GALLERY_DATA_PATH`, `PROBE_IMAGES_PATH`, `FACECHAIN_QI_CODE` as set).
3. `update-service` (rolling). Watch startup logs for **"Face engine licensed, T14 aFace preloaded
   and ready"** — if instead you see the `IllegalStateException` about `bpr.m10007.onnx`, Part B is
   missing; the deploy fails and the old task keeps serving (no outage).

### Verification
Enrol a student with a photo → confirm `<studentId>_00.jpg/png` appears under the gallery path.
Send a probe (or run a live camera). Within a couple of dedup cycles, `ActiveFilteredMatchFace`
should return the matched student, and the bNet chain should get named.

### Rollback
`update-service` back to the previous task-def revision (`FACECHAIN_MODE=OFF`). Part A is inert
without SERVER mode, so it is safe to ship ahead of B/C.

## Recommended follow-up (optional)
Bring the server matcher up to the desktop's **M12 + M14 fusion** for accuracy parity (the desktop
fuses both; the server uses AdaFace alone). Not required to fix the reported problem.

## Ownership
Parts B and C are production-deploy + licensing decisions (this service backs the portal's student
enrolment as well as bNet). Recommend doing C as a monitored rolling deploy with the rollback ready.
