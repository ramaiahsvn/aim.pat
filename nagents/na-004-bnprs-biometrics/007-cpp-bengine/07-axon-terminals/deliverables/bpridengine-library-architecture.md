# BprIDEngine — unified library architecture

**Status:** B1–B6 all cleared; only B7 remains · **gate PASSES on 5 modalities** · 2026-07-30
**Owner:** na-004/007 `cpp-bengine` (engine, ABI contract, build integration)
**Affects:** na-004/001–006 — every modality agent

## The requirement

1. `cpp-face` builds → **only `BprFace`**. Same for each modality agent.
2. Build `bengine` later → it **already contains** whatever `BprFace` gained.
3. **Identical method signatures** — a method exposed by `BprFace` is callable from
   `BprIDEngine.dll/.so`.

Requirement 3 drives everything. Two hand-maintained ABIs always drift, so the answer cannot be
"keep them in sync". It has to be structurally impossible for them to differ.

## Two mechanisms, both required

### 1. Generalized ABI — the signature is closed over the taxonomy

The libraries do not export per-modality functions. They export **one function set parameterised
by TID/MID** (`capi/bprid_abi.h`):

```c
int BprID_Extract(BprIDTemplateId tid, const BprIDSample* sample,
                  uint8_t* out_template, uint32_t* io_size);

int BprID_Match(BprIDMatcherId mid,
                const uint8_t* probe,   uint32_t probe_len,
                const uint8_t* gallery, uint32_t gallery_len,
                double* out_score, int32_t* out_raw);
```

`BprFace.dll` and `BprIDEngine.dll` export **exactly this**. They differ only in what
`BprID_ListTemplates()` returns. Swapping one for the other requires **no host code change**.

Ids encode the taxonomy directly — `(modality << 8) | variant`, modality being the table's own
`4A..4F`. So `T11 == 0x4A01`, `M52 == 0x4E02`. An id is self-describing on the wire and can sit
in a template header with no lookup table.

**Adding a modality never changes this header.** New algorithms arrive as new TID/MID values,
not new exported functions. That is what makes the ABI stable across all six agents working
independently.

### 2. Shared objects — the same bytes in both binaries

Signature identity is guaranteed by linking *the same compiled objects*, not by convention:

```
                ┌────────────────────────────────────────────────┐
                │ BprIDEngine.so/.dll        CONSOLIDATED        │
                │ engine core + ALL bprid_<m>_abi + <m>_algo     │
                └────────────────────────────────────────────────┘
                     ▲ links the SAME objects as ▼
   ┌────────────┬────┴────────┬────────────┬───────────┬─────────┐
   │ BprFace.so │ BprFinger.so│ BprFingerCK│ BprPalm.. │BprIris..│
   └────────────┴─────────────┴────────────┴───────────┴─────────┘
```

| Target | Type | Contents | Owner |
|---|---|---|---|
| `bprid_abi` | OBJECT | the generalized ABI + dispatch table | 007 |
| `bprid_common` | OBJECT | licensing, id/name helpers — **defined once** | 007 |
| `bprid_<m>_algo` | OBJECT | algorithm, from `src/BprIDEngine/<M>/*_src.cmake` | 001–006 |
| `bprid_<m>_reg` | OBJECT | registers that modality's TIDs/MIDs into the dispatch table | 001–006 |
| `Bpr<M>` | SHARED | `abi + common + <m>_algo + <m>_reg` | 001–006 |
| `BprIDEngine` | SHARED | `abi + common + ALL algo + ALL reg + engine core` | 007 |

`cmake --build . --target BprFace` → one modality.
`cmake --build . --target BprIDEngine` → all of them.

**Why OBJECT libraries, not static:** a linker pulls objects out of an archive only to resolve
an undefined symbol. Registration code is referenced by nobody, so a static archive would be
silently dropped and the consolidated library would export the ABI with an empty dispatch table.
**This was measured, not assumed** — before the fix, `nm -a libBprIDEngine.dylib | grep
fjfx_create_fmd_from_raw` returned nothing.

### How change propagation works

Both artefacts derive from the same two per-modality files:

- `src/BprIDEngine/<M>/*_src.cmake` — algorithm sources
- `cli/BprIDEngine/<M>/…` — that modality's registration

Add a file or a TID, and **both pick it up on the next build**. No second place to edit.
Requirement 2, satisfied structurally.

## Current state — verified 2026-07-30 by trial compilation

| Modality | `*_src.cmake` | `cli/` glue | root branch | glue builds `-DNO_MFC` | bengine adapter |
|---|:--:|:--:|:--:|:--:|---|
| BprFace | ✓ | ✓ dll+jni | ✓ | **✓** | — |
| BprFinger | ✓ | ✓ dll | ✓ | **✓** | ✓ T21 (Fjfx) |
| BprFingerCless | **✓** | ✓ dll | ✗ | ✓ | **✓ T31 (feeds T21)** |
| BprFingerKnuckle | **✓** | ✓ dll | ✗ | ✓ | **✓ T33/M32 (CompCode)** |
| BprPalmprint | **✓** | ✗ | ✗ | — | **✓ T41/M41 (CompCode)** |
| BprIris | ✓ | ✓ dll | ✓ | ✓ | ✓ T51/M51 |

## Blockers — each owned by one agent, all small

**B1 · ~~duplicate license symbols~~ — CLEARED 2026-07-30.** Now defined once in
`cli/BprIDEngine/common/bprid_common_abi.cpp`; the three glue files keep their declarations so
no exported surface changed. `BprLicVerification` consolidated on the FingerCless/Knuckle body
(size-0 guard + try/catch); BprFace's bare version gained both. `BprLicGeneration` could **not**
be merged — BprFace verified a hardcoded string while FingerCless/Knuckle printed developer
license codes and returned `true` unconditionally, so the common definition performs no
generation and returns `false`. *Original text:* `BprLicGeneration` /
`BprLicVerification` are *defined* in three glue files (Face, FingerCless, FingerKnuckle).
Linking all three is a duplicate-symbol error. Move to `bprid_common` as
`BprID_LicVerification`. The FingerCless/Knuckle body is the better one — size-0 guard plus
try/catch; BprFace's is bare and gains robustness. *001, 003, 004 + 007.*

**B2 · ~~`int main()` in the BprIris glue~~ — CLEARED 2026-07-30.** Removed; it was a leftover
harness extracting from a hardcoded `C:/BPR/DAta/img1.bmp`. *006.*

**B3 · ~~BprFinger glue is not portable~~ — CLEARED 2026-07-30.** `TemplateExtractnew` is now
inside the platform guard and uses `BPRIDFINGER_EXPORT`. Guarded rather than ported: `BSTR` and
`SysAllocStringByteLen` are Windows OLE and the function is a COM automation entry point by
nature. Non-Windows callers use `BprID_Extract(BPRID_T21, …)`. **All five glue files now compile
with `-DNO_MFC`.** *002.*

**B4 · ~~`NO_MFC`~~ — CLEARED 2026-07-30** via `add_compile_definitions(NO_MFC)`.
*Original text:* `AprCommon/BprUtils/bpr_utils_main.h` pulls `<afx.h>` (MFC)
unless `NO_MFC` is set; all five glue files inherit it. With `-DNO_MFC`, four of five compile
clean on clang. Set globally by the unified CMake. *007.*

**B5 · ~~CLEARED 2026-07-30~~.** All three done: Palmprint (CompCode), FingerCless (T31 preprocessing feeding T21) and FingerKnuckle (CompCode, PolyU baseline). *Originally:* ~~Palmprint~~ **cleared
2026-07-30** — Competitive Coding implemented, T41/M41 live, in the gate. FingerCless and
FingerKnuckle still have export glue wired to nothing and no sources; they share modality 4C,
so 003 and 004 must coordinate. *003, 004.*

**B6 · ~~`imread.cpp:557`~~ — CLEARED 2026-07-30.** Now `!= NULL`. BprIris builds off MSVC for
the first time. *006.*

**B7 · Fjfx is in no library.** `BprFinger/Fjfx` (FingerJetFX OSE) is referenced by nothing in
the root build. Root `BprFinger` ships **matching only** (M3gl + Nnmq → `Start_Iso_Fp_Matching`);
bengine's T21 is **extraction only**. Neither half is complete. Adding Fjfx to
`bpr_finger_src.cmake` closes it. **LGPL — clear with na-002-bnprs-core first.** *002.*

## Migration of the legacy exports

The existing names stay as a thin compatibility layer; they are not the contract:

| Legacy | Generalized |
|---|---|
| `Bpr_Face_Matching_T11(...)` | `BprID_Match(BPRID_M11, ...)` |
| `Bpr_FaceDetect_T12_Init(...)` | `BprID_Extract(BPRID_T12, ...)` |
| `Start_Iso_Fp_Matching(...)` | `BprID_Match(BPRID_M21, ...)` |
| `bpr_face_get_version()` | `BprID_Version()` |
| `BprLicVerification(...)` | `BprID_LicVerification(...)` |

The legacy names already carry TIDs (`_T11`, `_T12`), so the taxonomy was implicitly there — the
generalized ABI just makes it the parameter instead of part of the symbol name.

## Rules

1. **Never define a target named `Bpr<Modality>` inside bengine.** The root build owns those
   names; bengine's internals are `bengine_<m>_algo`. (Caught during design — the collision
   would have broken any future `add_subdirectory`.)
2. **Never re-declare a modality function in the engine.** Link the object. A copied signature
   is a signature that will drift.
3. **Dependency runs one way: engine → modality.** A modality library must never depend on
   `bengine_core`, or it stops being independently shippable.
4. **New capability = new TID/MID**, never a new exported function.
5. `extern "C"`, C types only across the boundary.

## Delivery order

1. **B4** `NO_MFC` — unblocks four glue files at once *(007)*
2. **B1** `bprid_common` license ABI — the actual consolidation blocker *(007 + 001/003/004)*
3. **B2**, **B3** one-line portability fixes *(006, 002)*
4. `bprid_modalities.cmake` wired into both builds *(007)*
5. **Proof gate** below must pass
6. **B7**, **B6** content fixes *(002, 006)*
7. **B5** the three missing modalities *(003, 004, 005)*

## Proof gate — PASSING

Automated as `bengine/tests/proof_gate.sh <build-dir>`; it diffs every `Bpr<Modality>` against
the consolidated library and fails on drift.

```
$ cmake -S . -B build-all -DBENGINE_BUILD_ALL=ON && cmake --build build-all
$ tests/proof_gate.sh build-all
PASS  libBprFinger.dylib         17 symbols
PASS  libBprFingerCless.dylib    17 symbols
PASS  libBprFingerKnuckle.dylib  17 symbols
PASS  libBprIris.dylib           17 symbols
PASS  libBprPalmprint.dylib      17 symbols
```

| Library | `BprID_*` | Registers |
|---|:--:|---|
| `BprFinger` | 17 | T21 bFinger |
| `BprIris` | 17 | T51 mIris |
| `BprFingerCless` | 17 | T31 bFingerCless *(ISO 19794-2, feeds from T21)* |
| `BprFingerKnuckle` | 17 | T33 bFingerKnuckle *(M32 reads T33)* |
| `BprPalmprint` | 17 | T41 bPalmprint |
| `BprIDEngine` | 17 | **T21 + T31 + T33 + T41 + T51** |

Identical ABI, different capability sets, consolidated = the union. Until iris landed the gate
compared one library against a superset of itself, which proved little — two modalities is the
first meaningful run.

Export hygiene alongside it — 26 total per library: 17 `BprID_*`, the 2 common license symbols,
and FingerJetFX's own 7 vendor entry points. Nothing else escapes.

### Two bugs the gate exposed

**`BprID_LibraryName` returned "BprIDEngine" from `libBprFinger`.** A compile-time define cannot
work: `bprid_abi.cpp` is compiled **once** and the same object lands in every library, so it has
no way to know which one. That is precisely the property the design depends on. Fixed with a
generated per-library source — the library's own name is the *only* thing not shared.

**Forcing default visibility on `bprid_abi`** so the ABI would export leaked **152** internal
symbols (bengine internals, AprCommon, STL) into every library. Now hidden, letting `BPRID_API`
mark exactly the entry points.

---

*na-004/007 cpp-bengine · 2026-07-30. Every fact here verified by inspection or trial
compilation, not inferred from directory layout. Contract header:
`bpr.cpp/src/BprIDEngine/bengine/capi/bprid_abi.h`.*
