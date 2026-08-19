# Letterbox preprocessing A/B — VALIDATION FAILED, do not ship (2026-08-19)

Closes the pending action "Validate the letterbox change with positive footage before any
publish." Verdict: **the letterbox preprocessing (bpr.cpp `529a1aa`) LOSES recall on both
detectors at every relevant operating point. It should be dropped (or reverted to stretch)
before any BprVision 2.61.2 publish.** "Correct by construction" did not survive measurement.

## Method

`letterbox_ab.py` (beside this file): one decode pass per clip, every 1-fps sampled frame scored
TWICE through OpenCV-DNN —
- **A = stretch**: `blobFromImage(frame, …, 640×640)` — the published 2.61.1 path
- **B = letterbox**: aspect-preserving resize onto a 114-gray 640×640 canvas — `529a1aa`

then the same offline (threshold × temporal gate) sweep as the 2026-08-16 accuracy report.
Corpora identical to that report: positives `vision-eval-positives/` (211 fight / 417 smoke),
negatives `UCF101_subset` (405). ~29k inferences per side.

**Cross-check that validates both runs:** column B reproduces the 2026-08-16 numbers exactly
(fight 3/8@0.50 → 36.0% recall / 3.2% FA; smoke 2/6@0.50 → 23.3% / 8.1%) — because `roc.py`
already scored letterboxed. So the parked verdict's numbers were letterbox numbers all along,
and the published stretch binary actually does BETTER on recall than the report measured.

## Results (clip-level; FA = fraction of 405 negatives alarming)

FIGHT — current gate 3/8:
| thr | recall A (stretch) | recall B (letterbox) | FA A | FA B |
|-----|-----|-----|-----|-----|
| 0.30 | 66.4% | 54.0% | 10.1% | 7.7% |
| 0.40 | 56.4% | 45.0% | 6.7% | 4.7% |
| **0.50** | **44.5%** | **36.0%** | **4.0%** | **3.2%** |
| 0.60 | 30.3% | 28.4% | 2.0% | 2.0% |
| 0.70 | 16.6% | 19.9% | 1.0% | 0.5% |

SMOKE — current gate 2/6:
| thr | recall A | recall B | FA A | FA B |
|-----|-----|-----|-----|-----|
| 0.30 | 44.4% | 37.9% | 19.8% | 13.8% |
| 0.40 | 36.5% | 29.3% | 12.8% | 9.4% |
| **0.50** | **29.0%** | **23.3%** | **10.4%** | **8.1%** |
| 0.60 | 23.5% | 17.3% | 7.7% | 5.9% |
| 0.70 | 13.4% | 9.8% | 3.7% | 4.2% |

(Full grids incl. fight 2/6 and smoke 3/8, 4/8 in the run log; same pattern throughout.)

## Reading

- Letterbox trades recall for false alarms at essentially constant ROC — and at MATCHED
  false-alarm rates stretch is equal or slightly better (e.g. fight: stretch 0.50 = 44.5%R/4.0%FA
  vs letterbox 0.40 = 45.0%R/4.7%FA). There is no operating point where letterbox wins.
- Likely mechanism: letterboxing a 16:9 frame surrenders ~44% of the 640×640 input to gray
  padding, shrinking the subject; the stretch distortion these YOLOs were supposedly hurt by is
  evidently something they tolerate (whatever their training pipeline nominally did).
- Caveat inherited from the corpus: web video, close-framed. On real CCTV (small, distant
  subjects) letterbox's subject-shrinking should hurt MORE, not less — the direction of this
  result is expected to hold.
- This does NOT reopen the parked live-alerting verdict. Stretch fight recall 44.5% @ 4.0% FA is
  better than reported but still nowhere near the ≥90% recall / <1 FA/cam/day bar. Review-assist
  only, unchanged.

## Actions

1. **Do not publish 2.61.2 with `529a1aa`'s preprocessing.** Revert the letterbox part (keep the
   carry-overlays and stale-box parts of that commit if wanted — they are display, not scoring).
2. The 2026-08-16 report's headline numbers should be read as LETTERBOX numbers; the shipped
   2.61.1 binary (stretch) performs better than reported: fight 44.5%/4.0%, smoke 29.0%/10.4%
   at the current points.
3. Per the ownership rule: 001-cpp-face owns the module — route the revert decision there.

Score caches: session scratchpad `ab_fight.pkl` / `ab_smoke.pkl` (session-temporary; re-run
`letterbox_ab.py fight|smoke` to regenerate, ~20 min total).
