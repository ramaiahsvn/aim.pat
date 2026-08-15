# Evaluation Spec — M21 (M3gl) and M24 (Nnmq) on FVC2004

**From:** na-004/002 cpp-finger · **To:** na-004/012 rnd-evaluations
**Date:** 2026-08-15 · **Status:** BLOCKED on prerequisites in §7

---

## 1. Ownership

Per rnd-evaluations' nucleus, the split is explicit and this document respects it:

| | owns |
|---|---|
| cpp-finger (this agent) | **does it compute the right thing** — the adapters, the matchers, the ABI wiring |
| rnd-evaluations | **how good is it** — protocol, pair lists, scores, thresholds, the numbers |

So: **the figures produced from this spec are rnd-evaluations', not cpp-finger's.** If the run
surfaces a defect, report it back here and re-measure after the fix — do not fix it there.

## 2. What is being measured

Two matchers over **one** template format. That is the point of the exercise: both consume the
same T21-format ISO/IEC 19794-2:2005 records, so any difference in the numbers is attributable to
the matcher and not to enrolment.

| MID | Name | Implementation | Score native scale |
|---|---|---|---|
| M21 | bFinger | `BprFinger/M3gl` (OpenAFIS) | similarity percentage 0–100 |
| M24 | Nnmq | `BprFinger/Nnmq` (`FingerIsoMatching`) | **unbounded matched-pair count** |

The M24 scale is the reason this evaluation exists in the order it does — see §6.

## 3. Data

```
/Users/bnprs/BPR/Datasets/db_fvc2004/DB1_A_ist_invtrcs
/Users/bnprs/BPR/Datasets/db_fvc2004/DB2_A_ist_invtrcs
/Users/bnprs/BPR/Datasets/db_fvc2004/DB3_A_ist_invtrcs
/Users/bnprs/BPR/Datasets/db_fvc2004/DB4_A_ist_invtrcs
```

These are ISO templates produced by **Innovatrics** (`invtrcs`), i.e. T22-format records, not
this engine's own extraction. Sibling folders hold the other producers — `_ist` (T21 bFinger) and
`_ist_aw` (T23 Aware) — which makes an extractor-interoperability study possible later on exactly
the same pair lists. Not in scope here.

### 3.1 The folders are NOT a clean FVC set — read this before generating pairs

| folder | total files | canonical `<finger>_<impression>.ist` |
|---|---:|---:|
| DB1_A_ist_invtrcs | 10,903 | **800** |
| DB2_A_ist_invtrcs | 11,106 | **800** |
| DB3_A_ist_invtrcs | 11,190 | **800** |
| DB4_A_ist_invtrcs | 6,210 | **800** |

The remainder are variant families: `_cc`, and `_m7 / _m10 / _m15 / _m20 / _m25 / _m30`, each also
in a `_cc` form. Their counts decline with the number (800, 799, 788, 762, 704 in DB1), which is
consistent with minutiae-count-limited templates that could not always be produced.

**Select canonical files with `^[0-9]+_[0-9]+\.ist$` and nothing else.** A glob of `*.ist` pulls in
~13× the intended data, silently changes the protocol, and produces a number that is not
comparable to anything.

### 3.2 The variant families are a second experiment, not noise

Once the baseline exists, `_mNN` gives a minutiae-count sensitivity curve on identical fingers —
directly relevant to M24, whose module caps at `MAX_MINUTIAE 200`, and to the paper's claim of
tolerance to poor extraction. Run it **after** the baseline, reported separately.

## 4. Protocol — FVC

Standard FVC evaluation over 100 fingers × 8 impressions:

- **Genuine:** all impression pairs within a finger — `C(8,2) = 28` × 100 = **2,800** per DB
- **Impostor:** first impression of each finger against the first impression of every other
  finger — `C(100,2) = **4,950**` per DB
- No cross-DB pairs. Report per DB; do not pool.

## 5. Metrics

Report per DB per matcher: **EER, FMR100, FMR1000, ZeroFMR**, plus mean match time in ms.

`FMR1000` is FNMR at FMR = 0.1% and is the figure that closes cpp-finger's pending item
*"Benchmark FMR@FNMR=0.1% on FVC2004"*.

### 5.1 Reference column — a reference, NOT a target

Medina-Pérez et al., *Improving Fingerprint Verification Using Minutiae Triplets*, Sensors 2012,
12, 3418–3437 (`bpr.cpp/docs/`), Table 3, M3gl row:

| DB | EER | FMR100 | FMR1000 | ZeroFMR | Time |
|---|---|---|---|---|---|
| DB1_A | 6.3 | 11.4 | 19.3 | 21.7 | 1.3 ms |
| DB2_A | 6.2 | 9.1 | 13.6 | 15.3 | 1.1 ms |
| DB3_A | 6.1 | 8.6 | 14.4 | 16.4 | 1.9 ms |
| DB4_A | 3.0 | 4.0 | 6.9 | 10.3 | 1.2 ms |

**Do not treat a miss against these as a failure.** Two independent reasons our numbers should
differ:

1. **The implementation deviates from the paper by design.** §5 of the paper builds m-triplets
   from each minutia's `c = 4` nearest neighbours; `M3gl/Template.cpp` uses a **Delaunay
   triangulation** instead. The paper attributes its tolerance to feature-extractor errors to its
   own construction, so the property most likely to move is exactly the one being measured.
2. **The templates are not the paper's.** These are Innovatrics-extracted; the paper used its own
   minutiae extraction.

Everything else checked out against the paper and matches: `t_l = 12`, `t_g = 12`, `t_a = π/6`
(`Param.h`), Eq (7)'s π/4 direction limit, Eq (5)'s three clockwise shifts (`MaximumRotations = 3`)
and the §5.3 score `n²/(|P||Q|)` (`Match.cpp:141`, scaled ×100).

## 6. M24's score scale is uncalibrated — this run is what calibrates it

M21 needs no calibration: its native score is already a percentage, so `normalized = raw/100`.

M24 returns an **unbounded count** of matched edge pairs (`finalScore += 1`). There is no divisor
in the source and no documented maximum, so the adapter takes a `saturation` value — the count
treated as similarity 1.0 — as a constructor parameter with a placeholder default. **Until this
evaluation sets it, M24's `normalized` is order-preserving but its absolute value is meaningless
and must not be thresholded or fused.**

Please derive `saturation` (and the three thresholds `distThreshold` / `dirThreshold` /
`multipletThreshold`, which M24 genuinely honours and for which **no known-good values exist
anywhere in the repo**) and report them back. They are call-site parameters by design, so applying
them is a one-line change and never an edit to the adapter.

Note EER/FMR/ZeroFMR are threshold-sweep metrics computed on raw scores, so they are **unaffected**
by the missing normalisation. The calibration is needed for deployment and fusion, not for this
report.

## 7. Prerequisites — none of this can run yet

**7.1 M21/M24 are not registered.** Both adapters exist and compile
(`bengine/{include/bengine/adapters,src/adapters}/finger_m3gl.*`, `finger_nnmq.*`, commits
`a8abe7f` / `0d11341`) but are **inert**: adapters are listed explicitly in `CMakeLists.txt`, never
globbed. Needed: a CMake target, a `{{kFing,4}}` catalogue entry plus `BPRID_M24` define, and the
registrar lines. The catalogue change is an ABI matter for **na-004/007 cpp-bengine** — M24 reads
T21, making it the first non-pairing matcher since knuckle moved to 4F.

**7.2 `bengine-eval` cannot consume pre-extracted templates.** It registers face extractors only
(`main.cpp:149–179`), builds a `Sample` and calls extract. This evaluation needs a mode that reads
a `.ist` file **directly into `Template::data`** with no extraction step. That is harness work, and
the harness is rnd-evaluations' — flagging it, not claiming it.

**7.3 No `--mid`.** The CLI selects `--tid` only. With two matchers over one template format, the
matcher must be selectable independently.

## 8. Known defects affecting interpretation

Four were fixed in `0d11341` before this spec was written, deliberately so that no baseline would
need discarding: two in `M3gl/Template.cpp` (triangles with first vertex 0 silently dropped; a
`size_t` underflow on zero triangles), one in `Nnmq` (an empty-body `for` left the matched-index
globals uncleared **between calls**, so results depended on match history), and the M3gl wrapper's
unconditional `return 0`.

**Still open, and it is in M24's matching path:**

```cpp
finger_iso_matching.cpp:290   for (int i = 0; i < PEP[i].count; i++)
finger_iso_matching.cpp:292       for (int j = 0; j < GEP[j].count; j++)
```

The loop bound is indexed by the loop variable, so termination depends on data at a position that
moves each iteration, and it can read entries `calculate_edgepair` never filled. These most likely
want `P.count` / `G.count`. **Left unfixed because the correct form is a guess.** If M24's numbers
look anomalous, start here — and report back rather than patching it there.

Also relevant: the Nnmq module is **not reentrant** (`distThr`/`dirThr`/`multiplet` are file-scope
globals, `P`/`G` are module buffers). The adapter serialises through a module-wide mutex, so M24's
timing figures are single-threaded by construction and are **not** comparable to M21's on
throughput. Compare per-match latency, not wall-clock over a batch.

## 9. Data handling

Per cpp-finger's core directives: **no fingerprint images and no minutiae templates in any output**
— not in the report, not in logs, not in committed artefacts. Scores, thresholds and aggregate
metrics only. `bengine-eval`'s own header states the same rule for embeddings.

## 10. Deliverable

Per DB per matcher: EER / FMR100 / FMR1000 / ZeroFMR / mean match time, DET curves, and the
calibration constants from §6. Report against §5.1's reference column with the two caveats stated,
so the comparison is not read as a pass/fail.

Onward: these numbers feed **na-004/010 algo-certify**, and any subsequent matching-threshold
change routes back through this agent per its guardrails.
