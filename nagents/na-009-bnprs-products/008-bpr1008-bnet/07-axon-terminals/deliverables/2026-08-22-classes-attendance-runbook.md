# Classes + Attendance + Merged Face Matching — Deploy & Test (2026-08-22, block 2)

Developed and committed, NOT deployed (user deploys). Builds verified.

## What changed since the last deploy (rev 48 = 15b79a9)

### Backend — local `uat_temp` = ba765bd (backup `cr-insights-portal`)
1. **10163af — AuditToFiltered ported** (the missing v1 link): scheduled 30s job
   (SERVER mode) copies each (FC label, camera)'s best-scoring identification_audit
   row into filtered_match_face for cameras with a class in progress
   (cameramapping.STATUS_ID=5), upgrading on higher scores; fills CAMERAMAPPING_ID
   (ActiveFilteredMatchFace filters on it). Without this, matches never reached
   attendance or the identified-people panel.
2. **ba765bd — ClassLiveStatus + attendance fixes**:
   - `GET /bnet/ClassLiveStatus?companyId`: today's timetable slots + per-class
     roster with present/absent (filtered_match_face in the slot window, 10-min
     grace), live flag, counts — one call drives the Classes page.
   - StudentAttendanceDto gains `studentId` (photos in the report).
   - getAttendance: in-progress class (null check-out) uses now-UTC as end
     instead of NPE-ing.

### Portal — local `uat_temp` = 487737a9 (backup `cr-portal-insights`)
1. **Operations merged into Face Matching** (user saw duplication): one page =
   engine state + matcher config + funnel + charts + recognised strip + decisions.
2. **Classes page** (menu 14, replaces Operations): today's schedule as per-class
   panels — faculty photo, time, zone, LIVE pulse, attendance % bar, student photo
   wall (present in colour with green check, absent desaturated with red mark).
3. **Attendance rework**: live session-by-student matrix per Faculty-Course group
   (photos, presence chips, % bars, 60s refresh); downloads demoted to a menu
   (PDF/Excel server, CSV client-side).

## Deploy
Same one-shot script (builds API from local uat_temp HEAD, rolling ECS deploy that
preserves env SERVER/4GB, then portal S3+CF — bundle pre-flight included):
```
! bash /private/tmp/claude-501/-Users-bnprs-BPR-GitRepos1-aim-pat/6f8cca39-ba1e-40af-b8a2-b374dbd1f061/scratchpad/deploy-all.sh
```
Note: push local uat_temp branches to origin after deploy if wanted (pushes
auto-trigger a harmless failing pipeline — offline runner).

## Live class demo — already staged and PROVEN up to the copier
- Timetable: course 1 (Java C01), faculty 2 (C Krishna Mohan), Zone-M4P, 2h window
  (created ~04:01 IST 2026-08-22; re-create a fresh slot if testing later — the
  Classes page shows TODAY's slots inside their windows).
- Faculty checked in on camera 6 → cameramapping STATUS_ID=5 (still active until
  checked out via portal Faculty CheckIn).
- Camera 6 "M4P-Webcam" (server id 6): local STREAM_URL points at the activity
  clip (`~/BPR/Datasets/activity-video/VideoClips/2026-08-03_115835_C5012.MP4`);
  local camera 3 idled (STREAM_URL/IP cleared). Webcam alternative: STREAM_URL='0'
  (untested — launchd daemon may lack macOS camera/TCC permission; the clip avoids it).
- RESULT so far: client chained 7 faces on cam 6, pushed; server identified
  Dilip 91%, Pattabhi 77–79%, Shanavas 77% from the video (audits 1707–1713).
- AFTER DEPLOY: within ~30s the copier turns those audits into filtered_match_face
  rows → Classes page shows the three present; Attendance matrix marks them; the
  desktop app's "Identified people" panel fills (ActiveFilteredMatchFace).

## Post-deploy test checklist
1. `GET /bnet/ClassLiveStatus?companyId=1` → the class with presentCount=3.
2. Portal → Classes: panel with photo wall (3 coloured + 2 grey).
3. Portal → Attendance (default last-7-days): matrix row P chips for the three.
4. Portal → Face Matching: funnel + charts now carry the cam-6 activity.
5. Desktop app Home → Identified people panel.
6. Faculty check-OUT (StartClass page) ends the session cleanly.

## Housekeeping (unchanged)
ECS exec still enabled (disable when done); Keycloak subdomain origin; token/secret
rotations; 9 pre-existing API test failures (NK).
