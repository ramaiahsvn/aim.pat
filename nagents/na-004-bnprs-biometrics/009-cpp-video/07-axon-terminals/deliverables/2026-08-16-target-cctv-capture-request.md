# Target-site CCTV capture request — fight & smoke detection

**Date:** 2026-08-16 · **From:** na-004/009 cpp-video · **For:** site / ops / deployment teams
(na-006 deployments, na-009/008 bNet), **cc** na-002 legal/compliance
**Why:** Our fight and smoke detectors are trained/validated on public web video, which does NOT
predict performance on real fixed CCTV (measured domain gap: a model at ~95% on its own test set
scores near-chance on out-of-domain footage). **We cannot validate or improve these detectors — or
honestly quote a false-alarm rate — without footage from the actual cameras they will run on.** This
is the prerequisite for all further model work.

## What we need, in one line

A few days of ordinary footage from representative cameras (to measure real false-alarm rates), plus
a set of **staged** fight and smoke events recorded **on those same cameras** (to get in-domain
positive examples, since real incidents are rare).

---

## 1. NEGATIVES — ordinary activity (the bulk; measures false alarms)

| item | ask |
|---|---|
| Cameras | **3–6 representative cameras** spanning the deployment: an entrance/corridor, an open area/yard, and at least one wide/distant view (small, far subjects — our hardest case). |
| Duration | **≥ 24 continuous hours per camera** (72 h is better), covering a full daily cycle: busy periods, quiet periods, **day AND night**, and typical weather. |
| Content | Whatever normally happens — people walking, standing, queuing, sports/play if it occurs, vehicles, lighting changes. **No events needed.** This is exactly the footage that generates false alarms, so it is the most valuable. |

Why continuous, not clips: a real per-camera-per-day false-alarm number can only come from
continuous camera-hours. 4–6 cameras × 24–72 h is enough for a first honest measurement.

## 2. POSITIVES — staged events (real incidents are too rare to wait for)

Record on the **same cameras, same angles** as above.

**Fight / violence** — safe, consented, acted scenarios by staff/volunteers:
- ~**20–40 short scenarios**, 10–30 s each: pushing/shoving, grappling, mock striking, a crowd
  converging, one person pursuing another. Vary distance from camera (near, mid, far), number of
  people (2, then a small group), and indoor/outdoor.
- Also record **~20 "looks like a fight but isn't"** clips: vigorous sports, energetic play,
  people hugging/greeting, running to catch a bus. These hard negatives are what separates a real
  detector from one that alarms on any fast motion.

**Smoke** — controlled and safe:
- ~**15–30 clips** using a **smoke machine / theatrical fogger** (safest) or a small controlled,
  supervised smoke source, at varying distance and lighting. Include **day and night**.
- Also ~10 "looks like smoke but isn't" clips: steam, dust, exhaust, fog, glare/haze — the common
  false triggers.

Staged-but-in-domain footage is far more useful than any public dataset, because it has your exact
camera optics, mounting height, angle, compression and lighting.

## 3. Format — capture NATIVE, do not transcode

- **Resolution / frame rate / codec:** exactly as the cameras record (H.264/H.265, whatever fps).
  Do **not** downscale or re-encode — we need the real deployment characteristics, including the
  compression artefacts.
- **Negatives:** long continuous files (hourly segments are fine).
- **Positives:** one file per staged scenario, ~10–30 s, trimmed to just before/after the event.
- **File naming:** `<siteid>_<cameraid>_<YYYYMMDD-HHMMSS>_<type>.mp4`
  where `type` ∈ `normal | fight | nonfight-hard | smoke | smoke-hard`.

## 4. Labels — light, temporal, no bounding boxes required

For the **staged** clips, a one-line-per-clip CSV/sheet is enough:

```
file, event_type, start_s, end_s, camera_id, distance(near|mid|far), lighting(day|night), notes
```

For the **negative** continuous footage: no per-frame labels needed — just note the camera, date,
and site. (If anyone happens to catch a *real* incident in the continuous footage, flag its file +
timestamp; those are gold.)

## 5. Privacy, consent & data handling — READ BEFORE CAPTURING (route via na-002)

This is footage of identifiable people; treat it as sensitive.
- **Staged scenarios:** get written consent from every participant for recording + use in model
  development.
- **Continuous/negative footage:** confirm the site's existing CCTV notice/policy and applicable
  privacy law (and any school/minor-specific rules) cover this use — **na-002 legal/compliance to
  confirm before capture**, not after.
- **On-prem only:** this footage must **not** go to any cloud API or third-party service (consistent
  with the on-prem product design). Transfer to us over an internal/secure channel only.
- **Retention:** state a retention/deletion plan up front; hold only what the model work needs.

## 6. Delivery

Copy to an internal secure location (an agreed on-prem/NAS path or encrypted drive) and notify
na-004/009. Do not email footage or upload to public storage.

---

## What we do with it, and why it unblocks everything

- **Negatives** → the first *honest* false-alarm-per-camera-per-day number (today's figures are an
  optimistic proxy) and the fine-tuning corpus for realistic non-events.
- **Positives** → an in-domain test set + fine-tuning data for the skeleton/ST-GCN approach
  (na-004/011), which broke the recall ceiling in prototype but could not be validated without target
  data.
- **Both** → the acceptance test for whether fight/smoke detection can be an alarm at all, or should
  ship as human-in-the-loop review-assist. **No further model work is measurable until this lands.**

**Priority order if capacity is limited:** (1) 24 h continuous from one wide/distant camera and one
busy corridor; (2) the staged fight scenarios; (3) the staged smoke scenarios; (4) more cameras /
longer durations.
