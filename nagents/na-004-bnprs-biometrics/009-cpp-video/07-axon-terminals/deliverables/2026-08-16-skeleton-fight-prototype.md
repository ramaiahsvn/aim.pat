# Skeleton-based fight detection — prototype result, and why it's PARKED

**Date:** 2026-08-16 · **Agent:** na-004/009 cpp-video (na-004/011 R&D lane) · **Status:** PARKED

> **Verdict: the recall ceiling IS breakable with skeletons, but a rushed ST-GCN overfits and does
> not generalize cross-dataset. The real blocker is the absence of target-domain CCTV footage — every
> proxy number here is confounded by domain mismatch. Hand "build it properly" to na-004/011 as a
> scoped R&D task, gated on capturing real site CCTV.**

## Why this was tried

The shipped YOLO fight model (bpr.m10006) has a hard **recall ceiling** — measured 36% recall @ 3.2%
false-alarm, and no tuning reaches past ~54% (see `2026-08-16-vision-detector-accuracy-and-class-inversion.md`).
na-004/011's three-tier report recommended skeleton-temporal models, and the public literature reports
~90–95% for skeleton methods on **RWF-2000** (2,000 real-surveillance clips). This prototype tested
whether that transfers to our use case.

## What was built (all self-contained; both mm-stack and the ultralytics wrapper are blocked here)

- **Pose:** YOLOv8n-pose ONNX on **onnxruntime directly** (na-004/011's proven path; the ultralytics
  wrapper phones home and hangs because github is unreachable from this network).
- **Model A — handcrafted:** 18 motion features (person count/proximity, body + arm wrist/elbow
  velocity & acceleration, interaction score) → small torch MLP.
- **Model B — ST-GCN:** a pure-torch implementation of Yan et al. 2018 (903k params: data-BN → 4
  spatio-temporal graph-conv blocks over the COCO-17 skeleton graph → pool → binary head). Input
  `[C=3, T=32, V=17, M=2]`.
- **Training set:** RWF-2000 train (350 Fight + 350 NonFight for the ST-GCN; 200+200 for the MLP).
- **Test sets:** cross-domain on our kinetics fight positives + UCF101 negatives.

## Results

| model / eval | recall @ 0.50 | false-alarm @ 0.50 | ROC-AUC |
|---|---|---|---|
| YOLO baseline (measured) | 36% | **3.2%** | — |
| A — handcrafted, kinetics-vs-UCF 5-fold | 67% | 31% | 0.738 |
| A — handcrafted, **RWF→our data (cross-domain)** | 76% | 56% | 0.667 |
| B — ST-GCN, **RWF in-domain (TRAIN-FIT)** | 95% | 0% | **0.995** |
| B — ST-GCN, **RWF→our data (cross-domain)** | 45% | 39% | **0.572** |

## Honest interpretation — read the two ST-GCN rows together

1. **The 0.995 in-domain is NOT a real number — it is train-fit.** It was evaluated on the same clips
   it trained on (loss fell to 0.06). It proves only that the architecture *can* fit RWF, which was
   never in doubt. A held-out RWF val split was not run — a methodology gap in this prototype.
2. **The 0.572 cross-domain is the real signal, and it is near chance** — *worse* than the handcrafted
   0.667. The ST-GCN (903k params on 700 clips, no augmentation, no person tracking, weakest pose
   model) **memorized RWF-specific patterns** instead of transferable violence structure, and
   collapsed on a different dataset.
3. **The recall ceiling IS breakable.** Handcrafted skeleton doubled recall (36% → 76%); the ST-GCN
   fit RWF to 0.995. So the *direction* (skeletons carry far more fight signal than frame-YOLO) is
   confirmed. What is NOT solved is generalization.
4. **Cross-DATASET proxy evaluation is unreliable in both directions.** YOLO 36%, handcrafted 0.67,
   ST-GCN 0.57 — every number is confounded by domain mismatch (RWF surveillance → kinetics web video
   → UCF sports, none of which is the target CCTV). The published 90–95% is **in-domain** (RWF→RWF) and
   does not claim cross-dataset transfer; our train-fit 0.995 is consistent with it.

## Why the ST-GCN did worse than the handcrafted model (it is not a paradox)

More capacity + little data + no regularization/augmentation + a hard domain shift = overfitting. The
handcrafted features are crude but domain-robust ("vigorous close multi-person motion" survives a
domain change); the ST-GCN learned RWF idiosyncrasies (camera framing, the pose extractor's
RWF-specific behaviour) that do not transfer. This is the expected failure mode of a rushed deep model
on a small set, not evidence the architecture is wrong.

## What would make it real (if resumed — scope for na-004/011)

- **Held-out RWF val split** — to get an honest in-domain number (does it even generalize in-domain?).
- **Regularization that fights overfit:** data augmentation (temporal crop, horizontal flip, joint
  jitter, scale), more training clips (RWF has 794+800 train), dropout/weight-decay tuning.
- **Better inputs:** person tracking for consistent M-ordering across frames; **RTMPose (Apache)**
  instead of YOLOv8n-pose (both stronger AND licence-clean).
- **The gate on all of it — real target-site CCTV footage.** Without it we cannot distinguish an
  overfit model from a good one, because every test set is a different domain. A few hours of site
  footage becomes both the honest test set and the fine-tuning corpus. This should precede more model
  work.

## Caveats carried forward (production blockers, unchanged)

- **Pose weights are AGPL** (YOLOv8-pose) — prototype only; ship RTMPose (Apache).
- **RWF-2000 is research-use only** — no commercial use without SMIIP Lab approval; a production model
  needs a commercially-licensed dataset.
- These compound the existing AGPL exposure on the shipped detectors (see the licence note in the
  nucleus).

## Reproduce

Code: `bpr.rnd/activity-recognition/` — `skel_fight.py` (pose + handcrafted features + MLP),
`stgcn.py` (pure-torch ST-GCN), `.venv` (torch 2.13 + onnxruntime + cv2), `yolov8n-pose.onnx`.
Data: RWF-2000 at `Datasets/activity-video/RWF-2000/` (research-only); our test sets under
`Datasets/activity-video/vision-eval-positives/` + `UCF101_subset/`.
Feature/sequence caches (`feat_*.npz`, `seq_*.npz`) and `model_stgcn.pt` are beside the code.
