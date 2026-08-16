# Fight detection — the class indices are INVERTED in our code

**Date:** 2026-08-16 · **Agent:** na-004/009 cpp-video · **Library:** BprVision 2.61.1
**Model:** `bpr.m10006.onnx` (YOLOv8-nano, Ultralytics, exported from PyTorch 2.10.0, opset 12)

> ## ⚠️ This document was rewritten the same day. Read this first.
> An earlier version concluded **"the model is not fit to ship."** That conclusion was **WRONG**.
> The measurements in it were real, but the attribution was not: I trusted the class mapping written
> in our source comment instead of reading it out of the model. **The model is fine. Our integration
> inverts its output.** The corrected numbers are below.

## The finding

`bpr.m10006.onnx` carries its class names in its own ONNX metadata:

```
names : {0: 'non_violence', 1: 'violence'}
```

`BprFightDetect.cpp` declares the exact opposite:

```cpp
// Classes: 0=violence, 1=no-violence  (only class 0 triggers alerts)   <-- WRONG
static const std::vector<std::string> FIGHT_CLASSES = {"violence", "no-violence"};
```

and then alerts on `det.classId == 0`.

**Class 0 is `non_violence`. Every "VIOLENCE DETECTED" alarm this library has ever raised was the
model confidently reporting that the scene is *not* violent.** The inversion cuts both ways: real
violence lands in class 1, which the code filters out and discards, so the detector would also
**stay silent during an actual fight**. It is not merely noisy — it is backwards.

## Evidence

Same harness, same corpora, same thresholds — only the class index changes.

**Negative corpus:** `Datasets/activity-video/UCF101_subset`, 405 clips of ordinary activity
(makeup, archery, baby crawling, balance beam, band marching, baseball, basketball, bench press).
**None contain violence**, so every alarm is a false alarm.

| | `classId == 0` (**our code**) | `classId == 1` (**model's own labels**) |
|---|---|---|
| clips raising a confirmed alarm | **230 / 405 — 56.8%** | **13 / 405 — 3.2%** |
| analysed frames firing | **1455 / 2460 — 59.1%** | **105 / 2460 — 4.27%** |

**Field corpus** — the two annotated CCTV clips in `Datasets/activity-video/VideoClips`, whose
`*.events.json` ground truth records a car turning and a man walking, no fighting:

| clip | our code (class 0) | corrected (class 1) |
|---|---|---|
| `jubli check post_toAVI.avi` | 13/26 frames, gate **confirmed 16x** | **0 frames, 0 alarms** |
| `MJ Market.avi` | 3/18 frames | **0 frames, 0 alarms** |

A **17.7x** reduction in clip-level false alarms and **13.9x** in frame-level firing, from one
index. On real field footage the false alarms disappear completely.

The earlier "median violence score on a negative frame is 0.604" statistic was the same mistake in
another costume: that was the model's *non-violence* confidence, correctly high on non-violent
footage. Likewise the "14:1 violence-to-no-violence box ratio" — the model was right 14 times out of
15 and the label was flipped on the way out.

## Method (unchanged, and still valid)

The C++ path was ported to Python on the *same* OpenCV DNN engine the library uses, and checked
line-by-line against the source:

- `BprYoloDetector::detect` — letterbox to 640x640, gray-114 fill, `1/255`, swapRB, conf `0.5`,
  NMS `0.45`, class by argmax over both classes, then filtered by class id.
- `BprVideoRunStream` sets `opt.throttleSecs = 1.0`, so production analyses ~**1 frame per second**;
  the harness samples at 1 fps to match. The 8-frame buffer therefore spans ~**8 seconds** of wall
  time, not 8 consecutive video frames.
- `BprFightDetect` temporal gate reproduced exactly: `bufferSize 8`, `minHits 3`.

Preprocessing was independently exonerated and remains so: solid gray-114, black, white and uniform
random noise all score **≤ 0.002** with zero detections under either mapping. The letterbox work is
a genuinely separate question and never had anything to do with these alarms.

## The fix

One line in `src/BprCCTV/BprVision/BprFightDetect.cpp`:

```cpp
static const std::vector<std::string> FIGHT_CLASSES = {"non_violence", "violence"};
```

and alert on `det.classId == 1` (three sites: `detectTemporal`'s filter, `_fight_detect_image`'s
`violenceCount`, and the red/green colour choice in `_fight_detect_image`). The header comment at
lines 23–24 must be corrected with it. **Take the names from the model's metadata, not from a
comment.**

Do **not** also change the confidence threshold in the same edit. The 0.5 default has never been
evaluated against a correctly-mapped detector, and the old negatives-only threshold sweep described
the wrong class entirely — it says nothing useful now and should not be carried forward.

## What still needs positives

With the mapping corrected the residual false-alarm rate is **3.2% of clips / 4.27% of frames** on
ordinary activity, which is a plausible operating point but is still only half a ROC. **Detection
rate remains unmeasured — there is no positive footage on this machine.** The kinetics-400 download
under way in `Datasets/activity-video/kinetics-dataset` carries usable proxies (*punching person*,
*wrestling*, *headbutting*, *slapping*, *side kick*); RWF-2000 or Hockey Fight would be better.
Until a positive set exists, do not tune the threshold and do not claim a detection rate.

Whether the skeleton-based direction (na-004/011) is still needed is now an **open question rather
than a settled one** — it was justified by false-alarm numbers that turn out to be an integration
bug. Re-evaluate that after the fix, against positives.

## The transferable lesson

This agent already carries the right instinct as Core Directive 3 — *"Read exports out of the built
artifact with `nm`, never from a header — they have disagreed."* This is the same failure in a
different guise: a **model's class names are part of the artifact**, and our source comment
disagreed with it for the entire life of the feature. The directive should be read to cover model
metadata, not just symbol tables.

## Smoke detection — checked the same way, 2026-08-16

**Class mapping is CORRECT.** `bpr.m10005.onnx` metadata says `{0: 'smoke'}`; `BprSmokeDetect.cpp`
declares `{"smoke"}` and alerts on class 0. Single-class model, so the fight inversion is not
possible here. Smoke was never affected by that bug.

Measured on the same 405 UCF101 clips (**none contain smoke**), using smoke's own parameters —
conf 0.5, NMS 0.45, `bufferSize 6`, `minHits 2`, 1 analysis/sec:

| measure | value |
|---|---|
| clips raising a confirmed alarm | **33 / 405 — 8.1%** |
| analysed frames firing | 141 / 2460 — **5.73%** |

Note the shape of this: smoke's **per-frame** rate (5.73%) is close to corrected fight's (4.27%),
but its **clip** rate is more than double (8.1% vs 3.2%). The difference is entirely the temporal
gate. Holding the per-frame detections fixed and varying only the gate:

| gate | clip false-alarm rate |
|---|---|
| **2 / 6 — smoke's current** | **33/405 = 8.1%** |
| 3 / 8 — fight's | 17/405 = 4.2% |
| 4 / 8 | 7/405 = 1.7% |
| 5 / 10 | 4/405 = 1.0% |

So smoke's gate is the loosest of the two while its per-frame error rate is the higher of the two —
the settings are inverted relative to the evidence. Adopting fight's existing 3/8 would **halve**
smoke's false alarms with no model change and no new model.

**But do not just tighten it.** Unlike fight, smoke is a fire-safety signal where latency is part of
the requirement, and at one analysis per second `minHits` translates directly into time-to-alarm:
2/6 can alarm in ~2 s, 4/8 needs ≥4 s, 5/10 needs ≥5 s and may take 10 s. **There is no positive
smoke footage on this machine either, so the detection rate — and what these gates cost it — is
unmeasured.** The gate is a latency/false-alarm trade that the fire-safety requirement should
decide, not a number to pick from this table.

False alarms concentrate on bright outdoor and gym scenes, consistent with haze, sky, dust and
lighting rather than anything smoke-like:

```
BaseballPitch 16/43 (37%)   BenchPress 14/42 (33%)   Basketball 12/44 (27%)
BabyCrawling  11/42 (26%)   BalanceBeam 7/37 (19%)   Archery     6/40 (15%)
BandMarching   4/42 (10%)   ApplyLipstick 3/37 (8%)  BasketballDunk 3/39 (8%)
```

## Reproducing

`fight_eval.py` (production path, class 0) and `fight_eval_c1.py` (class 1) sit next to this
document, along with `sweep2.py` (kept only as the record of the superseded sweep). They need only
`cv2` + `numpy` and read `.models/bpr.m10006.onnx` directly — no build.

```bash
cd /Users/bnprs/BPR/GitRepos1/bpr.cpp
python3 <deliverables>/fight_eval_c1.py "/Users/bnprs/BPR/Datasets/activity-video/UCF101_subset/*/*/*.avi"
```

Full 405-clip sweep runs in ~40 s, so this is cheap enough to be a standing regression gate. Read a
model's labels with:

```bash
strings -n 3 .models/<model>.onnx | grep -A1 '^names$'
```
