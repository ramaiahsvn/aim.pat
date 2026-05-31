---
name: project-na004-agents
description: "na-004-bnprs-biometrics: 12 active agents (001–012) covering BprIDEngine modalities + R&D + certification"
metadata: 
  node_type: memory
  type: project
  originSessionId: 4cd3a02c-667d-4ad2-a5bb-49b30d3c7376
---

na-004-bnprs-biometrics has 12 active agents (codes 001–012), all created 2026-05-27:

**Implemented modules (source in bpr.cpp/src/BprIDEngine/):**
- 001 cpp-face — BprFace: sFace_t12 (detect, recog, expression, fight, smoke, YOLO)
- 002 cpp-finger — BprFinger: Fjfx, Forg, M3gl, Nbis, Nfiq2, Nnmq
- 003 cpp-finger-cless — BprFingerCless: contactless preprocessing only (partial)
- 004 cpp-finger-knuckle — BprFingerKnuckle: L4/R4/T2 segmentation + matching
- 006 cpp-iris — BprIris: Masek (Gabor/IrisCode) + VASIR algorithms

**Not yet implemented (planned):**
- 005 cpp-palmprint — BprPalmprint (readme says "to be added")
- 007 cpp-dna — BprDNA (STR profiling)
- 008 cpp-sheep — BprSheep (livestock biometrics)
- 009 cpp-video — BprVideo (gait, multi-frame fusion, person re-ID)

**Cross-cutting:**
- 010 algo-certify — Certification (DET curves, FMR/FNMR, ISO 19794 compliance)
- 011 rnd-biometrics — R&D (algorithm research, dataset management)
- 012 rnd-evaluations — Evaluations (NIST-style protocols, EER, score distributions)

**Why:** Full biometric modality coverage for BNPRS BprIDEngine product line.

**How to apply:** When user references any biometric modality or BprIDEngine work — point to the relevant agent in na-004. Source repo: `/Users/bnprs/BPR/GitRepos1/bpr.cpp/src/BprIDEngine/`.
