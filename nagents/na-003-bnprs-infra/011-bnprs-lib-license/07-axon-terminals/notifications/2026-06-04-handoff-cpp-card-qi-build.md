# OUTGOING HANDOFF → na-005/002 cpp-card-qi

**Date:** 2026-06-04 · **Status:** SENT, awaiting cpp-card-qi

**What:** Requested cpp-card-qi build (1) the BprCardQi DLL with the new BGL file-load exports +
chokepoint lazy-load, and (2) the new `bgl-enroll.exe`. Source committed in bpr.cpp @ `f75cd85`.

**Delivered to:**
`na-005-bnprs-fintech/002-cpp-card-qi/01-dendrite/inputs/handoff-na003-011-bgl-build.md`

**Key notes flagged:**
- Suggested version bump 2.56.4 → 2.56.5 (additive ABI exports) — their bookkeeping.
- `bgl-enroll.exe` build: `x86_64-w64-mingw32-gcc -O2 -o bgl-enroll.exe ... -lwinhttp`, NOT `-municode`.
- **kid ordering:** interim test builds with kid=2 OK; final fleet DLL must embed grc-kms's chosen
  kid — 011 will ping cpp-card-qi to rebuild after updating `bgl_pubkeys.h`.
- Standing gap: no real-Windows-device hwid test yet.
