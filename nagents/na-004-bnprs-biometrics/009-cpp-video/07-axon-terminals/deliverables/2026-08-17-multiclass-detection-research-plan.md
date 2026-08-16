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
- **RESULT:** _pending (training queued behind dataset convert)._

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

## Compute reality & sequencing

The Mac trains one YOLO/MPS model at a time, so models are **sequenced**: fire/smoke → bulldozing →
(fight RTMPose / kissing baseline). Network jobs (downloads) and the running kinetics transfer +
MCES2 extraction proceed in parallel. Each model's result is appended here as it lands.

## Running state (updated live)

- Fire/smoke: dataset converting (D-Fire parquet → YOLO), training driver waiting then fine-tunes.
- Bulldozing: sourcing a reachable labelled dataset.
- Fight: prior results stand; RTMPose upgrade queued.
- Kissing: data source identified (Kinetics), baseline queued, legal flag raised.
