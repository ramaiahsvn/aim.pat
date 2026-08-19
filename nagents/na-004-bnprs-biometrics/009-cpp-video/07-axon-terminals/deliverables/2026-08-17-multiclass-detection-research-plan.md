# Multi-class CCTV detection — autonomous research session (2026-08-17)

**Agent:** na-004/009 cpp-video · **Mandate:** user gave a ~5h autonomous window to build the best
possible detectors for: **fire/smoke** (top priority), **fight/violence**, **bulldozing**, and
**intimacy/kissing (school safeguarding)**. Download public data as needed, fine-tune real models,
measure honestly. This document is the plan + live results log.

## Method discipline (carried from the fight prototype)

- **Never trust a claimed accuracy** — measure on a held-out labelled test set we control.
- **Report in-domain AND cross-domain**; flag domain mismatch.
- **Licence + provenance** recorded per model/dataset; AGPL/research-only flagged for production.
- github is unreachable from this network → all assets sourced from **HF / HuggingFace Hub / Roboflow
  / S3**. ultralytics runs offline once base weights are pre-fetched from HF (verified).

## Task 1 — FIRE / SMOKE  (priority; IN PROGRESS)

**Why tractable:** appearance-based object detection (YOLO's strength), large labelled benchmark.
- **Data:** D-Fire (21k labelled images, class 0=smoke 1=fire, YOLO format) via reachable HF mirror
  `badsaarow/d-fire` (parquet → converted to YOLO on disk at `Datasets/fire-smoke/dfire/`).
- **Base:** COCO-pretrained `yolov8s.pt` from HF `Ultralytics/YOLOv8` (github blocked).
- **Plan:** fine-tune yolov8s on D-Fire train (80 epochs, 640, MPS), eval on D-Fire test →
  mAP50 / mAP50-95 / precision / recall, per class. Published D-Fire yolov8 ≈ 0.75–0.85 mAP50.
- **Then (if strong):** ONNX-export for BprVision integration; optionally add FASDD/Pyro-SDIS for
  cross-domain robustness.
- **RESULT (2026-08-19):** 640-res fine-tune COMPLETE (80 epochs, `runs/dfire_yolov8s/weights/best.pt`):
  D-Fire test P 0.79 / R 0.73 / mAP50 0.79 — in the published band. (1280 refinement crashed at
  epoch 9 on an ultralytics-MPS TAL index bug — `resume_1280.log`; restartable, not blocking.)
  **VIDEO-ALARM eval vs shipped m10005** (`dfire_video_eval.py` beside this file; same corpora +
  gate-sweep as the 2026-08-16 report): at matched recall the D-Fire model HALVES false alarms —
  28.8% recall @ 5.7% FA (2/6@0.30) vs m10005's 29.0% @ 10.4% (2/6@0.50). Fire class: 1.0–1.7% FA
  on 405 negatives. Aggregate recall unchanged (~29%) BUT the per-class split shows the aggregate
  is dragged by proxy classes a correct detector SHOULD ignore: smoke recall 74.6% on
  `extinguishing fire` (real plumes) vs 3.7% on `juggling fire` (flame, NO smoke — and its FIRE
  recall is 64.8%, the right answer) and 8.9% on `barbequing` (often no visible smoke). Read:
  on genuinely fire-like footage this model works substantially better than any aggregate over
  kinetics proxies shows; the honest unknown remains real CCTV fire/smoke footage. NEXT: ONNX
  export + BprVision drop-in swap test; per-class-curated positives; ⚠️ weights are
  ultralytics-derived → AGPL question applies exactly as for m10005/6 — prototype only.

## Task 2 — BULLDOZING  (planned; object-detection, reuses Task-1 pipeline)

Bulldozer/heavy-equipment is an **object**, so the same YOLO fine-tune pipeline applies.
- **Data candidates:** Roboflow Universe (Heavy Equipment, Excavator/Construction Vehicle — YOLO
  format; needs a Roboflow API key) or HF construction-equipment mirrors. Will source a reachable
  labelled set and fine-tune yolov8s the same way.
- Note: "bulldozing" as an *event* (demolition in progress) may need temporal context beyond object
  presence; first deliverable is reliable *bulldozer/heavy-equipment presence* detection.
- **RESULT:** _pending._

## Task 3 — FIGHT / VIOLENCE  (extensively studied this session; see the two prior deliverables)

Established: YOLO frame model 36% recall (unfit); skeleton ST-GCN on RWF-2000 reaches **0.756
in-domain held-out** (full data + augmentation), plateauing below the literature's 0.87 (pure
skeleton) / 0.95 (RGB+skeleton fusion). Remaining levers, in impact order: **RTMPose** (Apache,
stronger + noise-free skeletons vs the nano pose used), **person tracking**, and **RGB+skeleton
fusion**. Cross-dataset transfer stays near-chance → **target CCTV footage is the gate**.
- **This session:** attempt the RTMPose upgrade if compute frees after fire/bulldozer; otherwise the
  scoped-R&D writeup + capture request already stand.

## Task 4 — INTIMACY / KISSING (school safeguarding)  ⚠️ HEIGHTENED REVIEW REQUIRED

**Purpose framing:** child-safeguarding — flag inappropriate behaviour between students for a human
reviewer. Treated technically as an action-recognition class, using ONLY established public academic
data; **no inappropriate content is collected or generated.**
- **Data:** Kinetics-400 already contains `kissing`, `hugging` classes (we have kinetics parts
  locally / on MCES2); public "kiss detection" movie datasets exist. Build a skeleton/video baseline
  the same way as fight.
- **⚠️ NON-NEGOTIABLE before any deployment — route via na-002 legal/compliance + safeguarding:**
  this involves **minors**; needs DPIA/legal basis, human-in-the-loop only (never autonomous action
  on a child), strict on-prem data handling, and safeguarding-policy sign-off. Flagged more strongly
  than any other task here. Prototype = research signal only; **not** a deployable classifier without
  that review.
- **RESULT:** _data identification done; baseline pending compute._

## VLM-as-judge MEASURED (2026-08-19) — `vlm_judge.py` beside this file

Qwen2.5-VL-7B-4bit (MLX, local) as a strict YES/NO judge, 8 frames/clip, scored with the same
recall/FA vocabulary as the detectors. Sample: 50 fight + 50 smoke positives (stride across
classes) + 60 UCF negatives per question (~±12% CI — sample, not the full corpora).

| task | recall | FA | speed |
|---|---|---|---|
| SMOKE | **56.0%** | **0.0%** | 10.5 s/clip |
| FIGHT | 26.0% | **0.0%** | 7.8 s/clip |

- **SMOKE: the best judge measured to date by a wide margin** — ~2x the recall of both the
  shipped m10005 (29.0% @ 10.4% FA) and the D-Fire prototype at matched recall (28.8% @ 5.7%),
  at ZERO false alarms on the adversarial UCF negatives. Per-class: extinguishing-fire 70%,
  hookah 73%, welding 50%, barbequing 27%.
- **FIGHT: the low aggregate is largely CORRECT judgment on bad proxies.** The prompt excluded
  sport, and the VLM obeyed: wrestling 88.9% caught, while boxing (37.5%), sword-fighting (8.3%)
  and slapping (0%) — mostly staged/sport clips — were rejected. 0 FA on sports-heavy negatives.
  Do not read 26% as "worse than YOLO's 36-44%": those YOLO numbers COUNT sport-alarms as wins
  on positives and pay 3-4% FA on negatives.
- **Economics unchanged:** 8-10 s/clip = tier-3 only (second opinion on tier-1 alarms,
  review-assist descriptions, offline auto-labeling for the licence-clean retrain). Qwen2.5-VL
  is Apache-2.0 — no AGPL entanglement.
- Verdict log for audit: `vlm_judge.jsonl` (session scratchpad; regenerate via the script).

## Compute reality & sequencing

The Mac trains one YOLO/MPS model at a time, so models are **sequenced**: fire/smoke → bulldozing →
(fight RTMPose / kissing baseline). Network jobs (downloads) and the running kinetics transfer +
MCES2 extraction proceed in parallel. Each model's result is appended here as it lands.

## Running state (updated live)

- Fire/smoke: dataset converting (D-Fire parquet → YOLO), training driver waiting then fine-tunes.
- Bulldozing: sourcing a reachable labelled dataset.
- Fight: prior results stand; RTMPose upgrade queued.
- Kissing: data source identified (Kinetics), baseline queued, legal flag raised.
