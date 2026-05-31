---
name: project-lib-forge
description: bnprs-lib-forge (na-003/009) publishes pre-built libs to GitLab; it does NOT build
metadata: 
  node_type: memory
  type: project
  originSessionId: 3e957bc2-5476-47e3-80bf-6ee8098cda91
---

`bnprs-lib-forge` (na-003-bnprs-infra, code 009) is a **distribution/publish agent only — it does not build or compile**. Building each library is done by other (domain/product) agents, which drop finished artifacts into `build/bnprs-libs/<Lib>/v<ver>/<platform>/` (git-ignored). The forge collects those, publishes them as GitLab Generic Packages, and serves consumers.

**Registry layout (decided 2026-05-30):** single GitLab project **`BPR1000/bpr1000.bnprs-libs`** (project id **230**, group `BPR1000` id 118; created 2026-05-30, private, packages enabled). Scheme: `package=<Lib>`, `version=<SemVer no-v>`, `file=<platform>/<file>` + `.sha256` + per-version `manifest.json`. Slash-in-filename verified working on CE 18.9. Versions immutable; read from source, never invented.

**Primary source repo:** `bpr.cpp` (github.com/ramaiahsvn/bpr.cpp) — CMake + Makefile, version source-of-truth in `src/AprCommon/BprVersions/bpr_versions.h`. Constraints: BprICBA/BprCardEmv are Windows-only; BprFinger/BprIris need a proprietary SDK; BprQiEmv is deprecated (never publish). Builds run on [[reference-build-host]] (pat-m4p).

**Why:** user explicitly scoped the agent to publishing only, and chose the single-project registry under bpr1000.
**How to apply:** never add build/cross-compile logic to this agent; when artifacts are missing, ask the responsible builder agent. Coordinate GitLab project/group creation with bnprs-gitlab (na-003/003); set host_project_id in 08-memory/long-term/libraries.yaml once created.
