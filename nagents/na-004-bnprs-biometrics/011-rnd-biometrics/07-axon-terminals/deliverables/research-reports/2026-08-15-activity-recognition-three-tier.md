# Activity Recognition for BprVision — Three-Tier Architecture Recommendation

**From:** na-004/011 rnd-biometrics · **To:** na-004/009 cpp-video (primary), na-004/001 cpp-face
**Date:** 2026-08-15 · **Prototype:** `bpr.rnd/activity-recognition/` (`side_by_side.py`, `vlm_lane.py`, results archived beside them)

## Question

The user needs accurate detection of varied activities in video, beyond BprVision's current
smoke/fight YOLO detectors. Are open-source models good enough, and which architecture fits a
continuous-CCTV biometric product?

## What was measured (all on this Mac, M4 Pro 24 GB, one afternoon)

Three tiers, same harness, same footage — two of the user's CCTV clips (distant people,
1920×1080), one 130 s close-range event video, and 8 labelled clips from the UCF101 subset
(now at `~/BPR/Datasets/activity-video/UCF101_subset/`, 405 clips / 10 classes with splits).

| Tier | Model | Result | Cost (measured) |
|---|---|---|---|
| 1 — always-on | YOLOv8n-pose, ONNX, CPU | tracked up to 19 people in a CCTV crowd scene where tier 2 saw noise | **42–44 fps sustained, CPU only** |
| 2 — per-window classifier | VideoMAE-base (Kinetics-400), MPS | **7/8 top-1 correct on labelled UCF clips**; pure noise (p≤0.11) on both CCTV clips | ~20 ms per 1.6 s window |
| 3 — per-event VLM | Qwen2.5-VL-7B-Instruct 4-bit, MLX, fully local | correct on all 3 UCF clips **including the one tier 2 missed** (Archery); coherent scene reading on CCTV; **read the book title off the event video** ("The True Card: Unseen Identity of Payments") | 2.8–4.6 s per event at normal resolution |

### The decisive findings

1. **The domain gap is proven in both directions on the same model.** VideoMAE scored 7/8 on
   standard footage hours after scoring noise (0.03–0.11) on the CCTV clips. Accuracy failure on
   CCTV is CAMERA GEOMETRY, not model quality — distant 22 px people are outside the Kinetics
   domain. Any RGB classifier will need fine-tuning on own footage; no download fixes this.
2. **The skeleton route survives CCTV geometry.** The pose stage extracted clean structure
   (counts, motion) from exactly the frames tier 2 failed on, in real time on CPU, on the same
   ONNX Runtime a C++ integration would use. Known limitation found: near-zero detection on a
   crawling baby (adult-pose prior) — relevant if fall detection matters.
3. **The VLM tier adds understanding, not just labels.** It caught tier 2's fine-grained miss
   (thin bow ≈ "cleaning gutters" to a 224 px classifier; obvious to world knowledge), read text
   in-scene, and gave an operator-usable description of the CCTV scene rather than hallucinating
   a class. It also retro-explained tier 2's confident mislabel on the event video ("shredding
   paper" 0.66 = someone unwrapping a book).

## Recommendation

**Adopt the three-tier hybrid.** This is also how commercial "hours of video in seconds" tools
work internally — sample/select, then describe — but on-prem, which a biometric CCTV product
requires (school footage cannot go to a cloud API; continuous VLM inference is economically
absurd at ~43 k minutes/camera/month anyway).

```
tier 1  pose/smoke/fight @ frame rate, CPU, always on   → selects interesting moments
tier 2  clip classifier on selected windows             → cheap label, AFTER fine-tuning on own footage
tier 3  local VLM on selected clips (seconds per hour)  → description, text-in-scene, alarm context
```

- Tier 1 next step: skeleton classifier head (PoseC3D/ST-GCN). Pre-extracted UCF101 skeleton
  annotations found at HF `kiyoonkim/ucf-101-posec3d` for bootstrap; fine-tune on own footage
  labelled via the new file-as-camera loop (bpr.cpp, 2026-08-15), which replays clips
  deterministically.
- Tier 3 next step: resize frames to ~1 MP before the VLM — the 90–100 s seen on 4K clips is
  vision-token count, not model speed; UCF-resolution clips took 2.8–4.6 s.
- Integration path: tier 1 is BprVision's existing pattern; tier 3 slots in as an event
  post-processor on the worker, not a stream component.

## Licence ledger (directive 4 — checked before attachment, not after)

| Component | Licence | Ship? |
|---|---|---|
| Qwen2.5-VL (tier 3) | Apache-2.0 | **yes** |
| MoViNet (tier 2 candidate) | Apache-2.0 | **yes** (unfetched — see environment) |
| PoseC3D/ST-GCN via MMAction2 | Apache-2.0 | **yes** |
| RTMPose (tier 1 ship candidate) | Apache-2.0 | **yes** |
| YOLOv8-pose weights (prototype tier 1) | AGPL-3.0 | **no** — prototype only, or Ultralytics commercial licence |
| VideoMAE checkpoints (prototype tier 2) | CC-BY-NC 4.0 | **no** — measurement only |

## Environment findings (cost real time; will again)

- **github.com is unreachable from this network** (clones time out; PyPI and HF fine). Cost the
  intended MoViNet prototype and the ultralytics .pt auto-download; HF mirrors substituted.
  Fetch GitHub-hosted assets from another network or via mces2.
- Python 3.14 + mm-stack (mmcv/mmaction2) do not yet mix; the PoseC3D HEAD was therefore not
  run — tier 1 measurements are pose-extraction + motion statistics. The classifier-head
  benchmark is the explicit next prototype step, via `kiyoonkim/*-posec3d` data or a pinned
  older Python.
- One-time model downloads dominate first-run latency (VideoMAE 330 MB, Qwen 5.5 GB); warm runs
  are seconds.

## Boundaries

Prototype quality throughout (rnd-biometrics directive 2): single-clip observations, not an
evaluation — accuracy numbers for any candidate that firms up go through na-004/012 with a
protocol. No biometric identification was performed; no face/template data left this machine.
