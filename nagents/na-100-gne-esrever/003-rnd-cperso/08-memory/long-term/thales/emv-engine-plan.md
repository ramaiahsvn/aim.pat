---
name: EMV Perso Engine in C++ - Planned Task
description: Build a complete EMV+Calypso personalization engine from scratch in C++; standalone PC/SC + SoftHSM; key specs still pending
type: project
---

> MOVED INTO AGENT MEMORY 2026-05-30 from source repo (trp1002.cperso.thales/project_emv_perso_engine.md,
> now deleted there). This is the agent's authoritative copy — task-002's headline deliverable.

## Task: Build EMV Personalization Engine in C++

**Status:** Not started — partially unblocked (4 of 6 decisions made 2026-05-30); still awaiting card profile spec + embossing format
**Target start:** ~2026-03-20

### Decisions locked (2026-05-30)
- **HSM:** SoftHSM (dev/test) — build behind an HSM-client interface, swap to real HSM later
- **Card type:** BOTH — EMV payment (Visa/MC) + Calypso ticketing (TRANSLINK-style); core must abstract profile/key schemes
- **Integration:** Standalone PC/SC + HSM — decoupled from the Windows-only MSVC6/MFC Thales stack
- **Platform:** PENDING (recommendation: cross-platform CMake, since standalone PC/SC + SoftHSM are both portable)

### What we're building
A C++ EMV card personalization engine that:
1. Parses embossing input files
2. Builds TLV/DGI data per card profile
3. Calls HSM for key derivation and crypto operations
4. Generates full APDU command sequence for card personalization
5. Handles error recovery and audit logging

### Core modules planned
- **TLV/DGI encoder** — EMV BER-TLV builder
- **APDU engine** — ISO 7816 command construction & response parsing
- **HSM client** — key derivation, MAC, encrypt via HSM API
- **Embossing parser** — read card data from input files
- **Perso sequencer** — orchestrates full personalization flow per EMV spec
- **GlobalPlatform SCP** — secure channel for applet management (if needed)

### Open questions
1. ~~**Target platform**~~ — PENDING final confirm (recommend cross-platform CMake)
2. ~~**HSM type**~~ — DECIDED: SoftHSM (dev/test)
3. ~~**Card type**~~ — DECIDED: Both (EMV payment + Calypso ticketing)
4. ~~**Integration target**~~ — DECIDED: (b) standalone with PC/SC + HSM
5. **Card profile spec** — EMV tag list with sources/values  *(STILL NEEDED)*
6. **Embossing file format** — field layout, delimiters, encoding, sample record  *(STILL NEEDED)*

**Why:** User has card profile specs, embossing file specs, and HSM access. Wants to write perso scripts from scratch per EMV standards rather than relying on Thales proprietary .per bytecode.

**How to apply:** When user resumes, start by confirming open questions, then architect and implement the C++ solution module by module.
