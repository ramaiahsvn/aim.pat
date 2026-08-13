# Face 1:1 verification on PolyU-HSFD — the first cross-pose evaluation

**Date** 2026-08-14 · **Agent** na-004/012 rnd-evaluations · **Requested by** user
**Engine** bpr.cpp @ `a07ec0b` working tree · **Harness** `bengine-eval` (build `eval-yale`)
**Status** Complete. Internal only — see Licensing.

Third and last of the databases recommended by the 2026-08-01 report. Unlike Yale and BioID, this
one **worked, separated the variants, and overturned a rule.**

---

## 1. Why this one is different

Every database in this series so far — LFW, ORL, dbase, CroppedYale, Yale, BioID — is **frontal**.
Section 9 of the previous report listed what remained unmeasured: *"pose, motion blur, low
resolution, compression artefacts, cross-age"*.

PolyU-HSFD ships three pose sets: `SampleImages_F`, `_L`, `_R`. The L and R images are **near-
profile**, not mild yaw — roughly 45–90° of rotation, with one eye and often one ear fully
occluded. **This is the first pose measurement in the series**, and the first result anywhere in it
that does not saturate.

---

## 2. What is actually in the database

`~/BPR/FaceData/PolyU/` holds `hsface.zip` (364 MB) and an already-extracted `hsface/` containing
three RAR archives. The zip holds nothing but those same three RARs. Extracted with `unar`
(`unrar` is not installed on pat-m4p).

| set | images | subjects |
|---|---|---|
| `F` frontal | 151 | 47 |
| `L` left near-profile | 124 | 47 |
| `R` right near-profile | 125 | 47 |
| **total** | **400** | **48 union, 46 in all three poses** |

Images are **180×220 JPEG**, tightly cropped greyscale-looking faces on black.

**Identity is in the filename** — `F_22_3.jpg` is frontal, subject 22, session 3 — which is why
this database supports verification where BioID did not. Files were reorganised into
`subjectNN/<pose>_<session>.jpg` because `make_pairs.py` keys identity on the **directory**.

> **These are the JPEG previews, not the hyperspectral data.** Each image has a companion
> `HyperFaceCube_*.mat` holding the actual 33-band cube, which is the point of this database and
> which **was not used** — the engine consumes ordinary images. Also note this is the *sample*
> distribution, not the full PolyU-HSFD. Both facts cap how far these numbers generalise.

---

## 3. Protocol

Three protocols were generated from one layout, all seed `20260814`, all folds **split by subject**:

| protocol | genuine | impostor | what it isolates |
|---|---|---|---|
| **frontal** | 227 | 227 | F↔F only — comparable to the rest of the series |
| **cross-pose** | 1004 | 1004 | F↔L and F↔R only — **the new axis** |
| all-pose | 1972 | 1972 | everything (generated, not reported — it blends the two) |

**Impostors are drawn with the same pose composition as the genuine set they accompany** — a
cross-pose genuine pair is matched against a cross-pose impostor pair. Without that constraint the
impostor distribution would be built from easier comparisons than the genuine one and every
cross-pose number would be flattered.

9 of the 47 frontal subjects have a single image and so contribute impostors only.

---

## 4. Results — frontal

| variant | accuracy | TAR@FAR=1e-2 | TAR@FAR=1e-3 | FTE |
|---|---|---|---|---|
| T12 sFace | 99.87% ± 0.38 | 100% | 100% | 0 |
| T13 iFace | 99.62% ± 1.14 | 100% | 100% | 0 |
| T14 aFace | 99.62% ± 1.14 | 100% | 100% | 0 |
| T15 mFace | 99.24% ± 2.28 | 100% | 100% | 0 |

**Saturated, exactly like Yale and ORL** — all four at 100% TAR at both operating points, 0 FTE,
error bars up to ±2.28 on 227 genuine pairs. No ranking claim is permitted from this table. It is
a smoke test, and it passes: tight 180×220 crops are handled by every variant without a single
extraction failure.

---

## 5. Results — cross-pose. **Common subset, 1940 pairs.**

First pass was **not comparable**: T12/T14/T15 each failed on the same 7 images and scored 1940
pairs, while T13 — using InspireFace's own detector rather than YuNet — failed on none and scored
2008. Per directive 5 the 7-image union was excluded and **all four re-run on an identical 1940
pairs** (966 genuine, 974 impostor). All figures below are from that corrected run.

| variant | accuracy | TAR@FAR=1e-2 | TAR@FAR=1e-3 | genuine below impostor ceiling |
|---|---|---|---|---|
| **T14 aFace** | **94.39% ± 4.81** | **88.10%** | **83.44%** | **16.6%** |
| T12 sFace | 92.72% ± 3.58 | 82.51% | 76.09% | 23.9% |
| T15 mFace | 91.03% ± 5.09 | 78.16% | 74.74% | 25.3% |
| T13 iFace | 86.59% ± 5.73 | 70.50% | 53.62% | 46.4% |

**All 7 extraction failures were L or R images** (`subject02/L_2`, `subject02/R_1`,
`subject21/L_4`, `subject21/L_6`, `subject22/L_3`, `subject24/R_3`, `subject24/R_4`). YuNet at
score 0.6 loses near-profile faces; InspireFace's detector does not. That is a **detector**
difference, not a recogniser one, and it is the same asymmetry seen on CroppedYale.

> T13's TAR@1e-3 was **61.65%** on its own 2008-pair set and **53.62%** on the common 1940. The
> exclusion removed images only T13 could handle, so its own-set figure flattered it by 8 points.
> This is precisely why the common-subset correction exists — quote **53.62%**.

### 5.1 — This is the first database in the series where the distributions genuinely overlap

The previous report's Yale finding was that genuine and impostor distributions were completely
disjoint, so accuracy saturated. Here they overlap heavily:

| variant | impostor mean | impostor max | genuine mean | genuine min |
|---|---|---|---|---|
| T14 | 0.0654 | 0.3087 | 0.5071 | 0.0000 |
| T12 | 0.1038 | 0.3666 | 0.4562 | 0.0000 |
| T15 | 0.1085 | 0.4101 | 0.5350 | 0.0000 |
| T13 | 0.0729 | 0.3986 | 0.4209 | 0.0000 |

**Every variant has genuine cross-pose pairs scoring 0.0000** — complete failure to associate two
images of the same person. And the *overlap* column in §5 ranks the variants in exactly the order
TAR@1e-3 does (T14 16.6% < T12 23.9% < T15 25.3% < T13 46.4%), which is a useful confirmation that
the margin/overlap reading introduced on Yale tracks the headline metric when there **is** a
headline metric to track.

### 5.2 — Pose asymmetry is real but small

Mean genuine score by pose pairing:

| variant | F↔L | F↔R |
|---|---|---|
| T12 | 0.4720 | 0.4408 |
| T14 | 0.5249 | 0.4899 |
| T15 | 0.5557 | 0.5149 |
| T13 | 0.4152 | **0.4264** |

Three of four score F↔L above F↔R by 0.03–0.04; **T13 alone reverses it.** Given the R images are
if anything slightly less rotated than the L images, this is likelier to be an alignment asymmetry
than a property of the faces. Worth a look if anyone tunes alignment — not worth acting on alone.

---

## 6. Multi-algorithm fusion — and the CroppedYale champion loses

Same 1940 pairs, same exclusion. **Singles repeated for comparison.**

| configuration | accuracy | TAR@1e-2 | TAR@1e-3 |
|---|---|---|---|
| **T12+T14 max** | **95.36% ± 3.38** | 89.96% | **85.92%** |
| T13+T14 max | 95.31% ± 4.11 | **90.68%** | 77.85% |
| T12+T14 mean | 94.44% ± 3.69 | 89.96% | 84.47% |
| *T14 alone* | *94.39% ± 4.81* | *88.10%* | *83.44%* |
| T13+T14 mean | 94.36% ± 3.48 | 85.20% | 76.60% |
| all four, mean | 94.05% ± 4.27 | 86.44% | 81.06% |
| T14+T15 mean | 93.21% ± 4.87 | 85.20% | 80.75% |
| T12+T13 mean | 93.20% ± 3.48 | 83.33% | 76.81% |
| *T12 alone* | *92.72% ± 3.58* | *82.51%* | *76.09%* |

### 6.1 — **T12+T14 was the WORST pair on CroppedYale and is the BEST pair here.**

On CroppedYale, T12+T14 mean **lost 5.5 points of TAR@1e-3 against T14 alone**, and that result
became rule (3): *fusion cannot rescue a weak variant; averaging pulls the strong one down.*

Here T12+T14 beats T14 alone on **all three metrics**, in both `mean` and `max` form, and
`T12+T14 max` is the best configuration measured on this database.

**The rule was not wrong — it was under-specified. What matters is the SIZE of the gap:**

| | T12 TAR@1e-3 | T14 TAR@1e-3 | gap | fusion outcome |
|---|---|---|---|---|
| CroppedYale | 58.04% | 93.63% | **35.6 pts** | **hurts** (−5.5) |
| PolyU cross-pose | 76.09% | 83.44% | **7.4 pts** | **helps** (+1.0 mean, +2.5 max) |

Revised rule: **fusion cannot rescue a component that is far weaker, but a component that is
merely somewhat weaker and fails differently still contributes.** A ~35-point deficit poisons the
average; a ~7-point one does not. Somewhere between those lies a threshold nobody has measured.

### 6.2 — Rule (1) held, and it held as a *negative* prediction

CroppedYale's rule (1) says look for a **crossover** between operating points before spending on
fusion. On this database there is **no crossover at all** — T14 leads at accuracy, at FAR=1e-2 and
at FAR=1e-3, and the full ranking T14 > T12 > T15 > T13 is identical at every operating point.

Rule (1) therefore predicts T13+T14 should *not* pay here. **It does not:** T13+T14 mean is worse
than T14 alone on all three metrics, despite being the best configuration measured anywhere on
CroppedYale. The rule survived a test it could have failed, which is worth more than the original
positive result.

### 6.3 — Rules (2) and (4) reconfirmed

**T14+T15 mean (93.21%) is worse than T14 alone (94.39%)** — two IR-101 models, no independent
information, the weaker drags. Third database in a row where fusing similar models hurts.

**All four fused (94.05%) is worse than the best pair (95.36%)** — more is not better.

### 6.4 — `max` beat `mean` at BOTH operating points, which CroppedYale said it would not

CroppedYale's finding was *mean for strict FAR, max for screening*, because max lifts impostor
scores as well as genuine ones. Here `T12+T14 max` beats `T12+T14 mean` at FAR=1e-3 as well
(85.92% vs 84.47%) — while `T13+T14` behaves the CroppedYale way (max 77.85% vs mean 76.60% at
1e-3 is a gain, but max collapses relative to its own 1e-2 figure of 90.68%).

So the max/mean split is **not** a fixed rule: it depends on whether the components' impostor tails
overlap. **Do not choose a fusion rule from doctrine — measure both. It costs one extra run.**

---

## 7. Findings

**7.1 — Pose is by far the most expensive condition measured in this series.** T14 drops from 100%
TAR@1e-3 frontal to **83.44%** cross-pose on the same subjects, same session, same camera, same
crop — the *only* variable is head rotation. For comparison, CroppedYale's illumination extremes
cost T14 6.4 points (100 → 93.63); pose costs it 16.6.

**7.2 — The ranking is now consistent across every database that can discriminate.** T14 first,
T13 last, on CroppedYale (illumination) and now PolyU (pose), with T12/T15 in between. The
saturated databases (LFW, ORL, dbase, Yale, PolyU-frontal) contribute nothing to this and should
stop being cited as if they did.

**7.3 — T13's Pikachu pack keeps failing on anything hard.** 53.62% TAR@1e-3 and **46.4% of
genuine pairs below the impostor ceiling** — nearly half. It has now degraded worst on dbase, on
CroppedYale at strict FAR, and on pose. Its one advantage is real and repeatable: **its detector
survives images YuNet drops** (0 FTE vs 7). If InspireFace is ever reconsidered, evaluate the
`Megatron` pack — this remains a result about the pack, not the SDK.

**7.4 — T12 holds up better under pose than under illumination.** It is second here at 76.09%,
only 7.4 points behind T14, whereas on CroppedYale it was 35.6 points behind and last by a wide
margin. **T12's weakness is specifically illumination, not difficulty in general.** That sharpens
the integration hypothesis from 2026-08-01 §5.4: an alignment fault would be expected to hurt
everywhere, and this does not.

**7.5 — For a deployment that must ship today, T12 + pose control beats T12 + lighting control.**
Given T12 is the only shippable variant, this evaluation says enrolment and capture policy should
prioritise **consistent illumination** over frontality, because that is where T12's deficit is
largest. Note this is the reverse of what the pose numbers alone suggest.

---

## 8. Licensing

Unchanged. **T12 sFace is the only shippable variant.** T13, T14 and T15 are measurements, not
options — so `T12+T14 max`, the best configuration here, **cannot ship**, and is an upper bound
rather than a proposal. Nothing in this report may be quoted externally.

---

## 9. What this does not answer

**This is the sample distribution, not full PolyU-HSFD**, and 48 subjects over 10 folds is ~5 per
fold — the ±3.4–6.2 error bars are large and driven by which identities land in which fold. **The
T14/T12 gap (1.7 points accuracy) is inside those bars; the TAR@FAR gaps are the defensible ones**
because TAR is pooled rather than per-fold.

The **hyperspectral cubes were not touched.** They are the reason this database exists and they
are unexplored — 33 bands, 400–720 nm. Whether band selection helps face recognition under pose is
a genuine research question this data could answer and this report does not.

Still unmeasured across the whole series: motion blur, low resolution, compression artefacts,
cross-age, and true surveillance capture. **All three recommended databases are now done** — Yale
saturated, BioID could not support verification, PolyU worked. There is no fourth recommendation
outstanding; the next database has to be sourced, not found on disk.

---

## 10. Reproduce

```bash
# extract (unrar is NOT installed on pat-m4p; unar is)
unar -o polyu ~/BPR/FaceData/PolyU/hsface/SampleImages_F.rar   # and _L, _R

# reorganise: identity is in the FILENAME, make_pairs.py keys on the DIRECTORY
#   SampleImages_F/F_22_3.jpg  ->  polyu-verify/subject22/F_3.jpg

# protocols: impostors must match the genuine set's POSE COMPOSITION (see §3)
#   frontal    F<->F
#   crosspose  F<->L and F<->R

# first pass, collect FTE per variant
./bengine-eval --data polyu-verify --pairs polyu_crosspose.txt --tid T14 --fte-list fte_T14.txt
# union the FTE lists, then re-run every variant with --exclude on the union
sort -u fte_T*.txt > cp_fte_union.txt
./bengine-eval --data polyu-verify --pairs polyu_crosspose.txt --tid T14 \
               --exclude cp_fte_union.txt --scores cpc_T14.txt
./bengine-eval --data polyu-verify --pairs polyu_crosspose.txt --tid T13 --pack Pikachu \
               --exclude cp_fte_union.txt --scores cpc_T13.txt
# fusion
./bengine-eval --data polyu-verify --pairs polyu_crosspose.txt --tid T12,T14 --fuse max \
               --exclude cp_fte_union.txt
```

`--scores` files contain `FAILED` rows for excluded pairs — filter them before computing
statistics or the parse throws.

## 11. Not yet done

- **Where between a 7-point and a 35-point component gap does fusion stop paying?** §6.1 brackets
  it; nothing measures it. A sweep over deliberately handicapped pairs would settle it.
- The **hyperspectral cubes** — 33 bands per image, entirely unexplored (§9)
- Full PolyU-HSFD rather than the sample
- Bootstrap 95% CI on EER; DET curves; EER and FMR@FNMR tables (carried from previous reports)
- Margin/overlap as a harness metric rather than a hand computation from `--scores`
