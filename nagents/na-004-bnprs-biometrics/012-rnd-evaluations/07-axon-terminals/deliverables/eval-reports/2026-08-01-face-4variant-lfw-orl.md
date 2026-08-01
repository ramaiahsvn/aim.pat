# Face 1:1 verification — all four BprFace variants on LFW and ORL

**Date** 2026-08-01 · **Agent** na-004/012 rnd-evaluations · **Requested by** user, via na-004/007 cpp-bengine
**Engine** bpr.cpp `9e412ff` · **Harness** `bengine-eval` (bengine/apps/bengine-eval)
**Status** Complete. **Internal only — see Licensing.**

---

## 1. What was evaluated

| TID/MID | Name | Model | Provenance |
|---|---|---|---|
| T12 / M12 | sFace | `bpr.m10002.onnx` | OpenCV SFace — **the incumbent, the only shippable one** |
| T13 / M13 | iFace | InspireFace `Pikachu` pack | HyperInspire SDK, built as libIFace |
| T14 / M14 | aFace | AdaFace IR-101 / WebFace12M | `bpr.m10007.onnx`, exported from the HF checkpoint |
| T15 / M15 | mFace | MagFace R100 / **Glint360K** | `bpr.m10008.onnx`, exported from the Vec2Face mirror |

> T15 is **not** the MS1MV2 checkpoint the MagFace paper reports — that one is Google-Drive only.
> Numbers here are therefore **not comparable to published MagFace figures**.

## 2. Protocol

Per directive 1 (document database, version, partition, protocol, date):

| | LFW | ORL / AT&T |
|---|---|---|
| Images | 13,233 / 5,749 people | 400 / 40 subjects, 92×112 **grayscale PGM** |
| Pairs | 6,000 (3,000 + 3,000) | 3,600 (1,800 + 1,800) |
| Source of pairs | official `pairs.txt` (converted from the shipped `.xlsx`) | **generated** — ORL publishes none |
| Genuine | official list | all within-subject, exhaustive (40 × C(10,2)) |
| Impostor | official list | sampled without replacement, seed 20260801, balanced 1:1 |
| Folds | 10, official partition | 10, **split by subject** |
| Threshold | fitted on 9 folds, applied to the 10th | same |
| Reported | mean ± std across folds | same |

Fold-fitting is per directive 4 — no threshold is chosen on the data it is scored against. ORL folds
split **by subject** so no identity appears in both the fitting and held-out sets; splitting by pair
leaks, and on 40 subjects that leak is worth a real fraction of a point.

Detector settings identical across all variants (YuNet, score 0.6 / NMS 0.3 / top-k 5000).
**All eight runs: 0 failure-to-extract.**

## 3. Results — LFW

| variant | accuracy | TAR@FAR=1e-2 | TAR@FAR=1e-3 | FTE |
|---|---|---|---|---|
| **T14 aFace** | **99.35% ± 0.34** | 99.01% | **98.87%** | 0 |
| **T15 mFace** | **99.33% ± 0.37** | 99.01% | 98.80% | 0 |
| T13 iFace | 99.02% ± 0.26 | 98.67% | 97.37% | 0 |
| T12 sFace | 96.60% ± 0.89 | 93.90% | 93.50% | 0 |

## 4. Results — ORL / AT&T

| variant | accuracy | TAR@FAR=1e-2 | TAR@FAR=1e-3 | FTE |
|---|---|---|---|---|
| T12 sFace | 99.91% ± 0.28 | 100% | 100% | 0 |
| T15 mFace | 99.80% ± 0.61 | 100% | 100% | 0 |
| T14 aFace | 99.68% ± 0.95 | 100% | 100% | 0 |
| T13 iFace | 99.64% ± 0.82 | 99.94% | 99.78% | 0 |

## 5. Findings

**5.1 — The ranking inverts, and ORL is the reason.** T12 is last on LFW by 2.8 points and first on
ORL. That is not T12 being good: it is **ORL being unable to discriminate**. All four fall within
0.27 points, error bars of ±0.28–0.95 overlap completely, and three of four saturate TAR@FAR=1e-3
at 100%. Forty subjects, controlled lighting, frontal, single session. *Per directive 5 — flag
insufficient statistical power:* **ORL cannot rank these algorithms and should not be used to.**
Use it as a smoke test.

It earned its keep as one: 0 FTE on 92×112 grayscale tight crops shows the detection and alignment
path handles input well outside LFW's shape.

**5.2 — T14 and T15 are a statistical tie.** 0.02 points apart against ±0.35 error bars. Any claim
that AdaFace beats MagFace here, or the reverse, is reading noise.

**5.3 — Read TAR@FAR, not accuracy.** The meaningful separation on LFW is at the authentication
operating point: T14/T15 ≈ 98.8% vs T13 97.4% at FAR=1e-3, i.e. **iFace rejects roughly 2.4× as
many genuine users** at a fixed 1-in-1000 false-accept rate. The accuracy column understates that
gap by more than half.

**5.4 — T12's deficit looks like integration, not the model.** Two independent signals:

- It is the **only** variant whose score depends on external pre-alignment: +0.77 points from
  `lfw-deepfunneled` (96.60 → 97.37), where T13 is −0.07, T14 −0.09, T15 −0.07. A recogniser
  sensitive to *someone else's* alignment is one whose own alignment is underperforming.
- Its fold-to-fold variance is **3× the others** (±0.89 vs ±0.26–0.37), consistent with some faces
  aligning well and others not.

Published SFace is ≈99.4%; measured here at 96.6%. **≈2.8 points appear to be recoverable on the
only variant that can currently ship.** Routed to na-004/001 cpp-face.

## 6. Licensing — none of this may be quoted externally

| variant | shippable | why |
|---|---|---|
| T12 sFace | **yes** | OpenCV, permissive |
| T13 iFace | no | InspireFace ships **no licence file**; packs are academic-only; no self-help path |
| T14 aFace | no | WebFace12M is academic-only. Architecture is MIT, so BNPRS-trained weights would be clean |
| T15 mFace | no | Glint360K is a research set. Architecture is Apache-2.0, same escape available |

T13/T14/T15 are **measurements, not options**. See na-004/007 mem-030 and mem-032.

## 7. What these benchmarks do not answer

Both LFW and ORL are frontal, well-lit and saturated. Neither says anything about CCTV-grade
imagery — which is the entire premise of an AdaFace-**CCTV** variant. A 99% here means the pipeline
is wired correctly, not that any of it suits surveillance capture.

Closer data already present in `~/BPR/FaceData`: **BioID** (marked-up, varied lighting), **Yale**
(illumination and expression extremes), **PolyU**. Recommended next evaluation.

## 8. Defects found by this evaluation

Both were invisible to unit tests, the proof gate and a clean build — only a benchmark could
surface them. Reported to cpp-bengine, fixed there (`e2a16b0`, `9e412ff`).

1. **Mirrored ArcFace alignment** in T14/T15 — 63.16% → 99.49% once corrected. Failed silently:
   detection succeeded, crops were face-shaped, self-matches returned 1.0. Only the relationship
   *between* images of one person was destroyed.
2. **Detector threshold mismatch** — `face_embed` used YuNet's default 0.9 where T12 uses 0.6,
   producing 70 extraction failures and scoring the two groups on different pair sets. After the
   fix, FTE 70 → 0 and accuracy moved within the error bars (T14 99.41 → 99.35).

## 9. Reproduce

```bash
# harness
cmake -S . -B build -DBENGINE_BUILD_FACE_T12=ON -DBENGINE_BUILD_FACE_T13=ON   # or T14/T15
cmake --build build -j8
ln -s <repo>/.models/bpr.m1000*.onnx <repo>/.models/Pikachu build/   # resolved beside the binary

# protocols
python3 apps/bengine-eval/protocols/lfw_pairs_from_xlsx.py ~/BPR/FaceData/LFW/pairs.xlsx pairs.txt
python3 apps/bengine-eval/protocols/make_orl_pairs.py      ~/BPR/FaceData/orl_faces  orl_pairs.txt

# run
./build/bengine-eval --data ~/BPR/FaceData/LFW/lfw   --pairs pairs.txt     --tid T14
./build/bengine-eval --data ~/BPR/FaceData/orl_faces --pairs orl_pairs.txt --tid T14
```

Do **not** use `--limit` for a reported number — it populates only the first folds and the
cross-validation degenerates. The tool prints `*** PARTIAL RUN — NOT AN LFW RESULT ***` when it
happens, but the figures below that banner still look plausible.

## 10. Not yet done

- Bootstrap 95% CI on EER (directive 3 asks for CIs; ± here is the across-fold std, not a bootstrap CI)
- DET curves and score-distribution histograms
- EER and FMR@FNMR tables — only TAR@FAR is computed today
