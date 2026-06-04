---
name: build-ownership
description: Who builds which bpr.cpp lib — BprCardQi is built by agent na-005/002 cpp-card-qi, not this agent
metadata:
  node_type: memory
  type: project
---

**BprCardQi DLL/.so/.dylib builds are owned by agent `cpp-card-qi` (na-005-bnprs-fintech / 002),
which holds the full build history.** This licensing agent (na-003/011) does **not** build
BprCardQi directly — it owns the licensing/gate *source* (`bpr_bgl.*`, `bgl/`, the gate at
`BprPcSc_Context_Init` / JNI `contextInit`, C ABI exports) and coordinates with cpp-card-qi to
get it compiled/shipped.

**Why:** user directive (2026-06-04) — "we will build the dll using our existing agent cpp-card-qi.
It has its full history of making." Building through that agent keeps the canonical build flow and
version bookkeeping in one place.

**How to apply:** when a BprCardQi build is needed (e.g. to ship the BGL gate), hand the build to
na-005/002 cpp-card-qi rather than running `make BprCardQi-*` here. This refines the nucleus
dependency line ("coordinate builds with the lib builders na-004/na-005"). Generic build entry
point if ever needed: `make BprCardQi-windows-64` (mingw-w64 toolchain) from `bpr.cpp` root.
See [[bgl-scheme]].
