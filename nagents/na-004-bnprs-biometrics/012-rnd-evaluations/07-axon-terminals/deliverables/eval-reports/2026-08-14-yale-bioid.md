# Face 1:1 verification on Yale, and detection on BioID

**Date** 2026-08-14 · **Agent** na-004/012 rnd-evaluations · **Requested by** user
**Engine** bpr.cpp @ `a07ec0b` working tree · **Harness** `bengine-eval` (build `eval-yale`)
**Status** Complete for Yale. **BioID verification is impossible — see §2.** Internal only.

Follow-up to `2026-08-01-face-4variant-lfw-orl.md`, which recommended BioID, Yale and PolyU as the
next databases. One of those three turned out not to support the protocol at all, and one turned
out to be already done under a different name.

---

## 1. Summary

| database | verification | detection | outcome |
|---|---|---|---|
| **Yale** (original, 15 subjects) | ✅ ran, all 4 variants | ✅ 0 FTE | **saturated — cannot rank** |
| **BioID** (1521 images) | ❌ **impossible, no identity labels** | ✅ ran, all 4 variants | **100% detection** |

Neither database changed the standing ranking. Both produced a usable negative result, and the
Yale score distributions produced one genuinely new ranking signal that accuracy and TAR@FAR both
hid — **§5.2**.

---

## 2. BioID cannot support a verification protocol — this is a property of the database

**BioID ships no identity labels.** From its own `description.txt`:

> The dataset consists of 1521 gray level images … Each one shows the frontal view of a face of one
> out of 23 different test persons. … The images are labeled "BioID_xxxx.pgm" where the characters
> xxxx are replaced by **the index of the current image**.

The filename encodes a **sequence index, not a subject**. There is no manifest, no per-subject
directory, and no identity column anywhere in the distribution — 1521 `.pgm`, 1521 `.eye`, one
`description.txt`. The 23 identities exist but are **not recoverable from what is on disk.**

A 1:1 verification protocol needs genuine pairs, i.e. two images known to be the same person.
Without labels there is no way to form one, so accuracy, TAR@FAR and EER are all undefined here.

**This was published as a face DETECTION benchmark**, which is what its ground-truth eye positions
are for. It was recommended in the previous report as "BioID (marked-up, varied lighting)" — the
mark-up is eye coordinates, not identity. That was my error in the earlier recommendation.

> **DO NOT "fix" this by running `make_pairs.py` on the BioID folder.** Its rule is *a subject is
> any directory that directly contains images*, so a flat BioID folder becomes **one subject with
> 1521 images**, and every one of the ~1.16 M within-folder pairs is emitted as **genuine** — pairs
> of 23 different people, all labelled same-person. The run would complete, print a plausible-looking
> table, and be pure noise. This is the same class of bug as the dbase `females/1` vs `males/1`
> collision, in the opposite direction.

**What was run instead** — a detection-rate measurement, which BioID *does* support: §6.

**To make BioID usable for verification** somebody must supply identity annotations. Third-party
subject labellings exist but are not in this distribution and were not downloaded; sourcing one and
verifying it is its own task, not a step inside this one.

---

## 3. "Yale" is two different databases, and one of them was already evaluated

`~/BPR/FaceData/Yale/` holds both:

| | contents | status |
|---|---|---|
| `CroppedYale/` | 38 subjects × ~64 illumination directions, 2452 pgm | **already evaluated** — §4c/4d of the 2026-08-01 report |
| `yalefaces.zip` | **15 subjects × 11 conditions, 165 images** | **not previously evaluated — this report** |

The previous report listed "Yale (illumination and expression extremes)" as a *recommended next*
database while already reporting results on CroppedYale. Those are different sets. Re-running
CroppedYale would have been redundant, so **this report evaluates the original Yale Face Database**,
which is the one that adds **expression** variation — CroppedYale is pure illumination geometry.

Conditions: `centerlight, glasses, happy, leftlight, noglasses, normal, rightlight, sad, sleepy,
surprised, wink`. 320×243 GIF.

### 3.1 Two data defects in the distribution, both corrected before the run

1. **`subject01.glasses.gif` is a byte-identical duplicate of `subject01.glasses`** (md5
   `bbf4e6ad…` for both). Left in, it becomes a genuine pair of *the same file*, which every
   matcher scores at 1.0 — free accuracy on an image that isn't a second sample. **Excluded.**
2. **`subject01.centerlight` does not exist; `subject01.gif` does**, is unique, and is the only
   subject01 file without a condition suffix. It is subject01's centerlight under a mangled name.
   **Renamed to `centerlight`**, restoring subject01 to 11 images like every other subject.

Left uncorrected, defect 1 inflates the score and defect 2 silently drops a subject to 10 images.
After correction: **15 subjects × 11 images = 165, exactly balanced.**

Images were converted GIF → PNG (`sips`) into a subject-per-directory layout, since the flat
`subjectNN.condition` naming carries identity in the *filename* and `make_pairs.py` keys identity
on the *directory path*.

---

## 4. Protocol

| | Yale |
|---|---|
| Images | 165 / **15 subjects** / 11 conditions each, 320×243 |
| Pairs | **1650** — 825 genuine + 825 impostor |
| Genuine | all within-subject, exhaustive: 15 × C(11,2) = 825 |
| Impostor | sampled without replacement, 1:1 balanced, seed **20260814** |
| Folds | 10, **split by subject** |
| Threshold | fitted on 9 folds, applied to the 10th |
| Detector | YuNet, score 0.6 / NMS 0.3 / top-k 5000 (T13 uses InspireFace's own) |

**Fold sizes are badly uneven — 252/235/218/216/192/120/123/105/96/93 pairs** — because 15 subjects
do not divide into 10 folds. Some folds hold two identities and some hold one. Per directive 5 this
is flagged, not hidden: see §5.1.

---

## 5. Results — Yale

| variant | accuracy | TAR@FAR=1e-2 | TAR@FAR=1e-3 | FTE |
|---|---|---|---|---|
| T15 mFace | 99.86% ± 0.42 | 100% | 100% | 0 |
| T13 iFace | 99.86% ± 0.42 | 100% | 100% | 0 |
| T12 sFace | 99.81% ± 0.56 | 100% | 100% | 0 |
| T14 aFace | 99.77% ± 0.69 | 100% | 100% | 0 |

All four scored the identical 1650 pairs — **zero extraction failures for every variant**, so no
common-subset correction was needed (unlike CroppedYale, which required excluding a 481-image
union).

### 5.1 — Yale cannot rank these algorithms. It is a smoke test.

The spread is **0.09 points across all four**, against error bars of ±0.42–0.69 that overlap
completely, and **all four saturate TAR@FAR=1e-3 at 100%**. Fifteen subjects, one session,
cooperative frontal capture.

This is ORL's finding again, and worse: ORL had 40 subjects and could not discriminate; Yale has
15. *Per directive 5 — insufficient statistical power:* **no ranking claim may be made from this
table**, including the apparent T15/T13 tie at the top and T14 at the bottom.

It earns its keep as a smoke test, and passed: **0 FTE on 320×243 GIF-derived greyscale including
hard directional lighting (`leftlight`/`rightlight`) and occlusion (`glasses`)** confirms the
detection and alignment path handles input well outside LFW's shape.

### 5.2 — The score distributions DO rank them, and the accuracy table hides it completely

Accuracy saturates because **the genuine and impostor distributions do not overlap at all.** For
every variant the *lowest* genuine score sits above the *highest* impostor score:

| variant | impostor mean | impostor **max** | genuine **min** | genuine mean | **margin** (gen min − imp max) |
|---|---|---|---|---|---|
| **T15 mFace** | 0.0472 | 0.2561 | **0.6215** | 0.8289 | **0.3654** |
| **T14 aFace** | 0.0352 | **0.1887** | 0.5448 | 0.8030 | **0.3561** |
| T13 iFace | 0.0545 | 0.2836 | 0.4863 | 0.7603 | 0.2027 |
| T12 sFace | 0.0917 | 0.3471 | 0.5395 | 0.7714 | 0.1924 |

**Zero errors are achievable at some threshold for all four** — that is what TAR@1e-3 = 100% is
really saying, and it is a stronger statement than "99.8% accurate".

**T14 and T15 hold ~1.85× the margin of T12 and T13** (0.356/0.365 vs 0.192/0.203). That is a
clean 2-vs-2 split which the accuracy column (0.09-point spread) and the TAR columns (all 100%)
both erase entirely. It is consistent in direction with CroppedYale, where T14 led T12 by 36 points
of TAR@1e-3 — the same ordering, visible here only because we looked past the saturated metric.

**Treat this as directional, not decisive.** Margin is a min-vs-max statistic over 825 genuine and
825 impostor pairs from 15 identities, so it rests on the two most extreme scores in the set and
has no error bar attached. It is worth reporting because it is the only axis on which this database
separated anything; it is not worth ranking on alone.

Note also that **accuracy is below 100% despite perfect separability.** With non-overlapping
distributions the only way to misclassify is to place the threshold outside the gap — so the
residual 0.14–0.23% is the 10-fold threshold *fitting* missing, on folds holding a single identity
(§4). It measures the protocol here, not the models.

### 5.3 — Directional lighting is the hardest axis, and it is the same axis for all four

Mean genuine score over every pair involving each condition:

| condition | T12 | T13 | T14 | T15 |
|---|---|---|---|---|
| **rightlight** | **0.7217** | **0.7141** | 0.7723 | 0.8020 |
| **leftlight** | 0.7350 | 0.7293 | 0.7855 | 0.8086 |
| **glasses** | 0.7389 | 0.7251 | **0.7720** | **0.8062** |
| surprised | 0.7505 | 0.7297 | 0.7843 | 0.8099 |
| centerlight | 0.7509 | 0.7434 | 0.7787 | 0.8100 |
| wink | 0.7543 | 0.7546 | 0.7927 | 0.8232 |
| sad | 0.7926 | 0.7693 | 0.8136 | 0.8356 |
| happy | 0.7931 | 0.7637 | 0.7970 | 0.8301 |
| sleepy | 0.7969 | 0.7902 | 0.8323 | 0.8514 |
| noglasses | 0.8204 | 0.8147 | 0.8452 | 0.8657 |
| **normal** | **0.8307** | **0.8287** | **0.8587** | **0.8746** |

The ordering is **near-identical across all four variants** — `rightlight`/`leftlight`/`glasses`
hardest, `normal`/`noglasses` easiest — which says it is a property of the *imagery*, not of any
one model. Expression (`happy`, `sad`, `sleepy`, `wink`) costs markedly less than illumination.
**Occlusion by glasses is as expensive as directional lighting**, and for T14/T15 it is the single
hardest condition.

Spread between the easiest and hardest condition, i.e. how much the score moves with capture
conditions:

| | T12 | T13 | T14 | T15 |
|---|---|---|---|---|
| range | 0.109 | **0.115** | 0.086 | **0.073** |

**T15 is the most condition-stable and T13 the least.** The hardest *pairs* are consistently
lighting-crossed (`glasses`↔`rightlight`, `leftlight`↔`surprised`, `rightlight`↔`wink`), and **not
one of them fell below the impostor ceiling for any variant** — the hard cases are harder, but none
of them break.

---

## 6. Results — BioID detection

Verification being impossible (§2), what BioID *can* answer is whether the detection and alignment
front-end survives "real world" capture: 1521 images, 384×286, deliberately varied illumination,
background and face size.

| variant | images | extraction failures | detection rate | extract |
|---|---|---|---|---|
| T12 sFace | 1521 | **0** | **100%** | 7.03 ms |
| T13 iFace | 1521 | **0** | **100%** | 9.97 ms |
| T14 aFace | 1521 | **0** | **100%** | 35.12 ms |
| T15 mFace | 1521 | **0** | **100%** | 36.81 ms |

**Every variant detected and extracted from every image.** For T12/T14/T15 that is YuNet at score
0.6; T13 is InspireFace's own detector. This is the largest and most varied set the front-end has
been run against — LFW is 13,233 images but far more uniform — and it produced no failures at all.

Timing reproduces the 2026-08-01 figures closely on a different database (T12 7.03 ms vs 8.57 ms,
T14 35.12 vs 35.04, T15 36.81 vs 35.25, T13 9.97 vs 9.83), which is a useful cross-check that the
timing method is stable: **the ~4× T14/T15 penalty over T12 is a property of IR-101, not of dbase.**

> **The accuracy figure from the BioID run is meaningless and must never be quoted.** The protocol
> pairs each image **with itself** as genuine — solely to force every image through extraction so
> the FTE list is complete — plus consecutive images as impostors to keep the fold arithmetic
> non-degenerate. Self-pairs score 1.0 by construction. **Read the FTE column only.**

---

## 7. Findings

**7.1 — Neither database changed the ranking, and that is the result.** Yale saturates; BioID
cannot rank at all. The standing recommendation from 2026-08-01 is unchanged: T12 is the only
shippable variant and closing its integration gap (≈2.8 recoverable points, routed to na-004/001)
remains the highest-value work.

**7.2 — Saturated accuracy is not the same as equal performance.** Yale ranked the variants 2-vs-2
by margin (§5.2) while showing a 0.09-point accuracy spread. **When accuracy saturates, look at the
score distributions before declaring a tie** — this is a new reading rule, and it is cheap: it needs
only `--scores`, no extra runs.

**7.3 — The front-end is solid on cooperative capture; the models are not the bottleneck there.**
0 FTE across 1521 BioID images and 165 Yale images, including directional lighting and glasses. All
remaining failure modes in this evaluation series come from illumination *extremes* (CroppedYale),
not from ordinary variation.

**7.4 — T12's weakness needs extremes to appear.** T12 scores 99.81% here and **89.92% on
CroppedYale**, with TAR@1e-3 of 100% vs **58.04%**. Yale's `leftlight`/`rightlight` is mild next to
CroppedYale's ±130° azimuth. A T12 deployment in controlled lighting will look fine; the same build
on surveillance-grade illumination will not. **Do not generalise a Yale-class result to CCTV.**

**7.5 — Glasses cost as much as directional lighting**, and are the hardest single condition for
T14/T15. Worth knowing for enrolment policy: an enrolment captured with glasses and a probe without
(or vice versa) is among the most expensive pairings in this set.

---

## 8. Licensing

Unchanged from 2026-08-01 §6. **T12 sFace is the only shippable variant.** T13 (InspireFace packs,
academic-only, no licence file), T14 (WebFace12M academic-only) and T15 (Glint360K research set)
are **measurements, not options**. Nothing in this report may be quoted externally.

---

## 9. What this does not answer

Same limitation as before, and it now applies to two more databases. **Yale and BioID are both
cooperative, frontal, indoor capture.** Neither says anything about CCTV-grade imagery, which is
the premise of an AdaFace-**CCTV** variant. CroppedYale remains the only set in this series that
genuinely stresses the models, and it stresses exactly one axis — illumination geometry.

Still unmeasured: pose, motion blur, low resolution, compression artefacts, cross-age — i.e. every
property that distinguishes surveillance capture from what has been tested. **PolyU** was the third
recommendation and holds 5 archive files, not yet unpacked or assessed.

---

## 10. Reproduce

```bash
# harness
cmake -S src/BprIDEngine/bengine -B build/cmake/eval-yale \
  -DBENGINE_BUILD_FACE_T12=ON -DBENGINE_BUILD_FACE_T13=ON \
  -DBENGINE_BUILD_FACE_T14=ON -DBENGINE_BUILD_FACE_T15=ON \
  -DBENGINE_BUILD_APPS=ON -DBENGINE_BUILD_TESTS=OFF -DCMAKE_BUILD_TYPE=Release
cmake --build build/cmake/eval-yale -j8
ln -sf <repo>/.models/bpr.m1000*.onnx <repo>/.models/Pikachu build/cmake/eval-yale/

# Yale: unzip, drop the duplicate, rename the mangled centerlight, GIF -> PNG,
# one directory per subject (see §3.1 — do not skip these steps)
unzip ~/BPR/FaceData/Yale/yalefaces.zip
#   exclude subject01.glasses.gif   (byte-identical duplicate of subject01.glasses)
#   subject01.gif -> subject01/centerlight.png
sips -s format png yalefaces/subjectNN.<cond> --out yale-verify/subjectNN/<cond>.png

python3 apps/bengine-eval/protocols/make_pairs.py yale-verify yale_pairs.txt \
        --folds 10 --seed 20260814 --ext .png
./bengine-eval --data yale-verify --pairs yale_pairs.txt --tid T14 --scores scores_T14.txt
./bengine-eval --data yale-verify --pairs yale_pairs.txt --tid T13 --pack Pikachu   # T13 only

# BioID: DETECTION ONLY. Self-pairs to force extraction; read the FTE list, never the accuracy.
./bengine-eval --data ~/BPR/FaceData/BioID-FaceDatabase-V1.2 \
               --pairs bioid_detect.txt --tid T12 --fte-list bioid_fte_T12.txt
```

`zsh` does not word-split unquoted parameters — `EXTRA="--pack Pikachu"` passed as `$EXTRA`
arrives as **one** argument and the run fails with a confusing path error. Use an array or write
the flags literally.

## 11. Not yet done

- **BioID identity annotations** — required before any BioID verification number can exist
- **PolyU** — 5 archives, unexamined; the last of the three recommended databases
- Bootstrap 95% CI on EER (± here is still the across-fold std, not a bootstrap CI)
- DET curves and score-distribution histograms — §5.2 is the argument for prioritising these
- EER and FMR@FNMR tables — only TAR@FAR is computed today
- Margin as a standing metric: if it survives on a database that *isn't* saturated, it is worth
  adding to the harness rather than computing it from `--scores` by hand
