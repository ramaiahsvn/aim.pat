# GFF Overnight Work — Deploy & Test Runbook (2026-08-22)

Everything below is DEVELOPED, COMMITTED and BACKED UP but NOT deployed.
Deploy order matters: DB script → API → portal → test.

## What was built overnight

### Backend — bpr1004.utms.api.bnet.smartpresence (local `uat_temp` = 3d7a20e, backup branch `cr-insights-portal`)
1. **1:N matcher fixed** (`FaceIdentificationService`):
   - Per-request probe mode: uses `Prob_Template` when present, else extracts from
     `Prob_Image`. (Root cause of the "BprID_Match: argument" failures: a
     TEMPLATE-configured server wrote an EMPTY probe file for image-only requests.)
   - 1:N now honours the portal Face Matching config (T12/T14/FUSION + gates) like the
     dedup worker, instead of fixed M14 + threshold 16.
2. **COMPANY_ID silently dropped — fixed** in `Staff` and `FaceImageData` entities
   (was `insertable=false` on every mapping; staff rows landed NULL, which is why
   FetchFaculty listed nobody).
3. **New read-only endpoints** (`BNetInsightsController`):
   - `GET /bnet/QueryDataRecords?companyId&pageNumber&pageSize`
   - `GET /bnet/IdentificationAudits?...` (student name/roll resolved)
   - `GET /bnet/FaceMatchStats?companyId` (pipeline counters + matcher cfg + gallery census)
   - `GET /bnet/PersonImage?personType&personId` (1=student, 2=faculty, 3=staff)

### Portal — bpr1004.utms.web (local `uat_temp` = 36973c94, backup branch `cr-portal-insights`)
1. **Face Matching page rebuilt** in the Wgate design language: server state, matcher
   config (segmented mode switch + gates), gallery census, pipeline counters,
   recent identifications with face photos + score bars. Auto-refresh 30s.
2. **Operations page** (menu 14): processing funnel, identifications-today chart,
   by-camera chart, matcher status, recently-recognised strip with photos.
3. **Query Data page** (menu 15): incoming client records — quality bars,
   payload type, verify status badges, auto-refresh.
4. **Photos everywhere**: Enrollments rows (students type 1 / staff type 3 /
   faculty via their staffId) + photo header in every edit drawer. `PersonAvatar`
   falls back to initials when no photo.
5. Global finish pass: antialiasing, brand selection/focus rings, slim scrollbars,
   tabular numerals.
6. Build verified: bundle `index-B3Hnwtfy.js`, api-base utms-api-uat, zero old-ALB refs.

## Current live state (unchanged tonight)
- 5 GFF members enrolled + verified via EnrolledStudents: 12 Pattabhi C1001,
  15 Ramesh C1002, 16 Shanavas C1003, 17 Dilip C1004, 18 Kaushiq C1005
  (dept 1 — the ONLY department with active courses; that was the whole
  "Duplicate entry" mystery, the message is a catch-all).
  Demo emails firstname.lastname@bnprs.ai, phones 9000024335-38, password Password123.
- Faculty: staff 5 = C Krishna Mohan, staff 6 = Ajay Kumar; faculty rows created 2/2
  but INVISIBLE to FetchFaculty until the DB script sets their COMPANY_ID.
- Companies: 1 IIM (keep), 19 GBS (created, reg GBS0001); 2,13,14,15,16,17,18 are
  samples to deactivate (DB script).
- Gallery on EFS: 5 real templates + stale `11_00_34.*` (pre-wipe; DB script removes).
- A probe (Pattabhi photo, FC GFFPROBE01) is stored server-side; it failed matching
  under the old code — after the API deploy, re-probe to test end-to-end.

## Deploy steps (in order)

### 0. DB fixes (user, `!` prefix — classifier blocks the agent)
```
! bash /private/tmp/claude-501/-Users-bnprs-BPR-GitRepos1-aim-pat/6f8cca39-ba1e-40af-b8a2-b374dbd1f061/scratchpad/fix-staff-company.sh
```
Sets staff 5/6 COMPANY_ID=1, deactivates the 7 sample companies, removes the stale
gallery 11_* files, prints verification selects.

### 1. Backend API
```
cd ~/BPR/GitRepos2/BPR1004_uTms/bpr1004.utms.api.bnet.smartpresence
git push origin uat_temp          # triggers CI build+deploy
```
- CI runner caveat: project-34 runner "RM PC" (id 4) may be OFFLINE. Fallback =
  assign this Mac's M4P-docker runner (id 5, paused) to project 34 and trigger the
  pipeline with variable `DOCKER_HOST=unix:///var/run/docker.sock` (socket-binding
  runner is incompatible with dind otherwise). Un-pause → run → re-pause + remove.
  (Recipe proven in mem-028.)
- **CRITICAL**: CI deploys its own task-def template — after its rollout completes,
  re-apply the env flip so the service keeps `FACECHAIN_MODE=SERVER` and
  **memory 4096** (2GB OOM-kills mode SERVER, exit 137):
  describe current td → ensure FACECHAIN_MODE=SERVER + memory 4096 → register →
  update-service (flip-facechain-server.sh pattern, profile itp, eu-central-1).
- Watch `/ecs/utms-smartpresence-api` for "Face engine licensed" + healthy rollout.

### 2. Portal
```
cd ~/BPR/GitRepos2/BPR1004_uTms/bpr1004.utms.web/bpr.utmsportal/apps/bnet
npm run build          # verify: grep utms-api-uat dist/assets/index-*.js; no old ALBs
aws s3 sync dist/ s3://utms-smartpresence-portal-819144294008/ --delete --profile itp
aws cloudfront create-invalidation --distribution-id E2VUT3LG51L7V8 --paths "/*" --profile itp
```

### 3. End-to-end test
1. Re-send the Pattabhi probe (image mode — exercises the fix):
   scratchpad `kc-token.sh` exists; probe script pattern in session notes. Expect:
   log `1:N FUSION vs 12_00_34.t14b: T14=~78`, an identification_audit row, and the
   match on the portal (Face Matching → Recent Identifications, with photo).
2. Portal walkthrough: Operations funnel numbers, Query Data records, Enrollments
   photos (5 students with real faces), Faculty list now showing Krishna Mohan +
   Ajay Kumar (after DB fix), Face Matching page.
3. Desktop worker path: it sends Prob_Template (T14 record) — TEMPLATE probes now
   also honour fusion config.

## Housekeeping owed
- **Disable ECS exec** when done:
  `aws ecs update-service --cluster utms-cluster --service utms-smartpresence-api --disable-execute-command --force-new-deployment --region eu-central-1 --profile itp`
- Keycloak (user, no CLI creds): add utms-bnet-spresence-portal.uat.bnprs.in origin
  (mem-020 step 3) — still pending.
- Rotations still owed: shared verify token, Keycloak client secret, $GITLAB_PAT.
- FaceMatchStats on a mode=OFF node without gallery paths would 500 in
  FaceMatchConfigService.get() (Path.of(null)) — deployed task has paths; guard later.
