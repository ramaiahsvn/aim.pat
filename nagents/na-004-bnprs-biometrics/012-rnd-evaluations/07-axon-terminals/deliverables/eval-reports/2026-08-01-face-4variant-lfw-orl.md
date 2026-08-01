# Face 1:1 verification — all four BprFace variants on LFW, ORL, dbase and CroppedYale

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

| | LFW | ORL / AT&T | dbase |
|---|---|---|---|
| Images | 13,233 / 5,749 people | 400 / 40 subjects, 92×112 **grayscale PGM** | 677 / **61 subjects**, 640×480 colour JPEG |
| Pairs | 6,000 (3,000 + 3,000) | 3,600 (1,800 + 1,800) | 6,994 (3,497 + 3,497) |
| Source of pairs | official `pairs.txt` (converted from the shipped `.xlsx`) | **generated** | **generated** |
| Genuine | official list | all within-subject, exhaustive | all within-subject, exhaustive |
| Impostor | official list | sampled w/o replacement, seed 20260801, 1:1 | same |
| Folds | 10, official partition | 10, **split by subject** | 10, **split by subject** |
| Threshold | fitted on 9 folds, applied to the 10th | same | same |
| Reported | mean ± std across folds | same | same |

**dbase subject keying:** it numbers subjects 1..n *separately* inside `females/` and `males/`, so
all 22 female ids also exist as male ids. Subjects are keyed by **full relative path**
(`females/1` ≠ `males/1`); keying on the leaf name would have merged 22 pairs of different people
and manufactured false genuine pairs.

Fold-fitting is per directive 4 — no threshold is chosen on the data it is scored against. ORL and
dbase folds split **by subject** so no identity appears in both the fitting and held-out sets;
splitting by pair leaks, and on 40–61 subjects that leak is worth a real fraction of a point.

Detector settings identical across all variants (YuNet, score 0.6 / NMS 0.3 / top-k 5000).
**Failure-to-extract: 0 on LFW and ORL; 2 images on dbase — the same 2 for every variant**, so all
four saw an identical pair set in every case. Per directive 5, that parity is the precondition for
comparing them at all.

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

## 4b. Results — dbase

| variant | accuracy | TAR@FAR=1e-2 | TAR@FAR=1e-3 | FTE |
|---|---|---|---|---|
| T14 aFace | 98.64% ± 3.85 | 96.83% | **96.83%** | 2 |
| T15 mFace | 98.60% ± 3.84 | 96.80% | 96.68% | 2 |
| T12 sFace | 98.39% ± 3.83 | 96.77% | 96.36% | 2 |
| **T13 iFace** | **95.08% ± 3.72** | 90.39% | **84.39%** | 2 |

Same 2 extraction failures for every variant, so all four saw an identical 6,940 scored pairs.

## 4c. Results — CroppedYale (illumination extremes)

38 subjects × ~64 lighting directions, azimuth −130°…+130°, elevation −40°…+90°, 168×192
grayscale. 20,000 pairs generated (10,000 genuine, capped and sampled, + 10,000 impostor).

**Scored on a COMMON SUBSET.** First pass FTE differed by variant — T13 388, the others 418 —
because T13 uses InspireFace's own detector rather than YuNet, so it survives images the others
drop. Different FTE means different pair sets and therefore no valid comparison (directive 5).
Each variant's failures were collected with `--fte-list`, unioned (**481 images**), and every
variant re-run with `--exclude` on that union: **12,924 pairs, identical for all four.**

| variant | accuracy | TAR@FAR=1e-2 | TAR@FAR=1e-3 |
|---|---|---|---|
| T13 iFace | **98.27% ± 0.56** | **97.28%** | 81.74% |
| T14 aFace | 97.69% ± 1.11 | 96.53% | **93.63%** |
| T15 mFace | 96.54% ± 0.98 | 93.99% | 89.56% |
| T12 sFace | **89.92% ± 2.30** | 74.75% | **58.04%** |

## 4d. Multi-algorithm fusion — CroppedYale, same 12,924 pairs

| configuration | accuracy | TAR@1e-2 | TAR@1e-3 |
|---|---|---|---|
| **T13+T14 mean** | 98.75% ± 0.68 | 98.60% | **96.27%** |
| T13+T14 **max** | **98.86% ± 0.57** | **98.85%** | 93.13% |
| all four, mean | 97.75% ± 0.97 | 96.58% | 91.70% |
| T14+T15 mean | 97.46% ± 1.10 | 96.19% | 92.85% |
| T12+T14 mean | 96.32% ± 1.46 | 93.55% | 88.17% |

A pair is scored only if **every** listed variant extracted both images, so fused runs and their
components share a pair set.

## 4e. Processing time — dbase 640×480, single-threaded, per call

| variant | extract | match | first call (incl. model load) |
|---|---|---|---|
| T12 sFace | **8.57 ms** | 12.73 µs | 47.5 ms |
| T13 iFace | 9.83 ms | **0.48 µs** | 15.2 ms |
| T14 aFace | 35.04 ms | 0.65 µs | 202.9 ms |
| T15 mFace | 35.25 ms | 0.67 µs | 197.0 ms |

The first extraction pays the lazy model load and is excluded from the mean; cache hits are not
timed. The first-call figure is load *plus* one inference, so T14's true load is ≈168 ms.

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

**5.3b — dbase is the first set to separate anything, and it separates T13 downwards.** iFace
drops from 99.02% (LFW) to 95.08%, and its TAR@FAR=1e-3 collapses from 97.37% to **84.39%** —
roughly **1 genuine user in 6 rejected** at a 1-in-1000 false-accept rate, against ~1 in 30 for
the other three. The other three land within 0.25 points of each other. The likely explanation is
that `Pikachu` is InspireFace's *lightweight edge* pack; a small model degrades faster than IR-101
when the data stops being frontal and clean. **If T13 is ever seriously considered, evaluate the
`Megatron` pack instead — this result is about the pack, not necessarily about InspireFace.**

**5.3c — read dbase's ±3.8 before ranking on it.** The error bar is ~10× LFW's and near-identical
across all four variants (3.72–3.85), which says it is driven by *which subjects landed in which
fold*, not by the models: 61 subjects over 10 folds is ~6 subjects per fold, so one hard identity
moves a whole fold. **The 0.25-point spread between T12/T14/T15 is far inside that and means
nothing.** T13's ~3.5-point deficit is around one std — suggestive on accuracy alone, but the
TAR@FAR gap is decisive because TAR is computed over the pooled score set rather than per fold.

**5.3d — CroppedYale is the only set that genuinely stresses these models, and it reorders them
twice.** Two findings that none of the other three databases could have produced:

*T12 collapses.* 89.92% accuracy, and **TAR@FAR=1e-3 of 58.04% — roughly 42% of genuine users
rejected** at a 1-in-1000 false-accept rate, against 93.63% for T14. On LFW it trailed by 2.8
points; under illumination extremes it trails by 36. Whatever is wrong with T12 (5.4) is far more
costly on hard imagery than LFW suggested.

*T13 and T14 cross over between operating points.* T13 has the **best** accuracy (98.27%) and the
best TAR@1e-2 (97.28%), but tightening to FAR=1e-3 costs it 15.5 points (→81.74%) while T14 loses
only 2.9 (→93.63%). A heavier impostor tail: T13 separates the bulk well but has more extreme
false-accept scores, so it degrades fast as the threshold tightens. **For authentication, which
lives at strict FAR, T14 is 12 points better than the variant that "wins" on accuracy.** This is
the clearest possible case for directive-driven reading of TAR@FAR rather than accuracy.

*AdaFace finally separates from MagFace.* Tied on LFW (0.02), ORL and dbase; here T14 leads T15 by
1.15 points and by **4.1 on TAR@1e-3**. That is the direction the `-CCTV` naming predicts — a
quality-adaptive margin should pay off precisely where quality varies — and it is the first
evidence in this evaluation for choosing between them.

**5.3e — Fusion pays, but only between components that fail differently.** T13+T14 beats *both*
on all three metrics, and at TAR@1e-3 by **+14.5 points over T13** and +2.6 over T14. The
predictor was §5.3d's crossover — direct evidence they misclassify different faces. Three
negative results matter as much: **T14+T15 came out worse than T14 alone** (two IR-101 models
fail on the same faces, so the weaker drags), **T12+T14 lost 5.5 points of TAR@1e-3 against T14
alone** — fusion cannot rescue a weak variant, averaging pulls the strong one down — and **all
four is worse than the best pair.** Choose complementary components, not many. `max` and `mean`
split by operating point exactly as the crossover predicts: use **mean for strict FAR, max for
screening**.

**5.3f — timing reframes the whole comparison.** T14/T15 cost **4× T12's extraction** (35 ms vs
8.6 ms) because IR-101 is 260 MB against SFace's 37 MB. T12 is not only the sole shippable
variant, it is also the cheapest — which raises the value of fixing it (5.4) above what the
accuracy table alone suggested. Conversely the best configuration measured anywhere, T13+T14,
costs ~45 ms per image **and cannot ship**: an upper bound, not a proposal. Matching is
effectively free (sub-µs), so a 100k gallery adds ~50 ms to a 35 ms extraction — **enrolment is
the bottleneck, not gallery size.**

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

LFW and ORL are frontal, well-lit and saturated; dbase is posed indoor capture. None of the three
says anything about CCTV-grade imagery — which is the entire premise of an AdaFace-**CCTV** variant. A 99% here means the pipeline
is wired correctly, not that any of it suits surveillance capture.

dbase is a step closer — 640×480 posed indoor capture, more varied than ORL — and it already
changed the ranking, which is the point. But it is still cooperative capture, not surveillance.

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
python3 apps/bengine-eval/protocols/make_pairs.py ~/BPR/FaceData/orl_faces orl.txt   --ext .pgm
python3 apps/bengine-eval/protocols/make_pairs.py ~/BPR/FaceData/dbase     dbase.txt --ext .jpg

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
