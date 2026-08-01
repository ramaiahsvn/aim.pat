# BprCCTV packaging — decision and outcome

**Decision (user, 2026-08-01): SPLIT.** `BprVideo` and `BprVision` ship as their own libraries,
built the same way as `BprFace` through the root `CMakeLists.txt`.
**Built and verified the same day.** na-004/001 recommended keeping one binary on the size numbers
below; the user decided to split and that decision stands. The analysis is kept because it records
what the split costs and what to watch.

---

## 1. What was built

| library | version | macOS | linux-x64 | windows-64 | exports |
|---|---|---|---|---|---|
| `BprVideo` | **2.60.0** | 5.4 MB | 7.7 MB | 26 MB | `Bpr_Video_Version`, `Bpr_Video_ProbeSource` |
| `BprVision` | **2.61.0** | 12 MB | 18.6 MB | 39 MB | 8 × smoke/fight + `Bpr_Vision_Version` |
| `BprFace` | 2.24.116 | 16 MB | 24 MB | 16 MB + 52 MB deps | 21, **unchanged** |

Self-contained on every platform, Windows included — neither new DLL needs a companion deps DLL.

Version lines sit **outside** the 2.24.x biometric range and outside the 6xx–8xx reserved modality
band: neither library identifies anyone or produces a template, so putting them in the biometric
line would make 2.24 stop meaning "biometric". They follow the BprCardQi/BprCardEmv convention of
their own `MAJOR.MINOR`. Recorded in all **three** places that must agree — `bpr_versions.h`,
`bpr_versions.cmake`, root `Makefile` — per the 2.24.116 lesson.

Build them exactly like BprFace:

```bash
cmake -S . -B build -DOUTFILENAME=BprVideo  -DPROJECTTYPE=SO_Linux -DOpenCV_DIR=...
cmake -S . -B build -DOUTFILENAME=BprVision -DPROJECTTYPE=DLL_Windows -DCMAKE_TOOLCHAIN_FILE=...
```

`SO_Linux` and `DLL_Windows` only — the branches `FATAL_ERROR` on anything else rather than
silently producing nothing, because neither has been tried on Android or iOS.

## 2. The constraint this creates — read before deploying

**`libBprFace` still exports the same eight `Bpr_SmokeDetect_T12_*` / `Bpr_FightDetect_T12_*`
symbols.** They were not removed, because removing them breaks every existing host — the .NET
sample links them directly. So the two libraries **overlap**:

```
host wanting face AND smoke/fight   ->  libBprFace alone      (as today, nothing changes)
host wanting smoke/fight ONLY       ->  libBprVision alone
host loading BOTH                   ->  duplicate symbols, undefined winner
```

This is the same shape as the `BprIDEngine` lean/`-face` split that cost a deployment team time and
was withdrawn in 2.24.902. The difference is that it is **documented and deliberate** here rather
than silent, and there is a clean exit: when `BprFace` next takes a major version it should shed
those eight symbols and the overlap disappears. Until then, treat it as a deployment rule.

`BprVideo` has no overlap — its two exports are new.

## 3. What the split costs, measured

Our own object code across all three folders is **0.4 MB**. The rest is static OpenCV:

| | macOS |
|---|---|
| own object code, all three components | 0.4 MB |
| one combined library | 15.6 MB |
| **static OpenCV share** | **15.2 MB — 97%** |

Deploying all three now costs **≈33 MB on macOS** against 15.6 MB combined. The three do not
partition OpenCV cleanly, because `dnn` (9.8 MB) is needed by **both** BprVision (YOLO) and
BprFace (SFace/YuNet), and `core` + `imgproc` (8.8 MB) by all three. BprVideo is the one real
saving — 5.4 MB, because transport needs no `dnn` at all.

So the split pays off **only** for a host that wants video transport without any detector. For
anything that detects, it is duplicated payload.

Also now true, and worth planning for: **three publish paths instead of one.** Each library × four
registries (generic, Maven, NuGet, Go) if the wrappers are extended to them, each with its own
version line, POM, csproj, loader and release note.

## 4. What to watch

1. **The overlap in §2** is the live risk. Anyone who puts `libBprFace` and `libBprVision` in one
   process gets undefined behaviour, and both report plausible versions, so it will not be obvious.
2. **Three versions must move together** whenever `IBprFrameAnalyser` or `BprFrameCallback`
   changes — those types cross the library boundary and nothing but discipline enforces agreement.
3. **`BprVideo` exports no `BprVideoRunStream`.** The loop is driven through a C++ interface that a
   C host cannot construct, so exporting it would be a false promise. C consumers get the camera
   probe and the version; C++ consumers link the headers. If an external host ever needs to drive
   the loop, that needs a real C-callable design, not an added export.
4. `BprVision` links the BprVideo sources directly rather than linking the library, so smoke/fight
   streaming works standalone. If BprVideo later becomes a shared runtime dependency instead, that
   is the moment to switch and to introduce version checking between them.
