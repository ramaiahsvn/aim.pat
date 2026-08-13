# Agent DNA — bruid-kms-phsm

> This is the nucleus. Claude reads this file at the start of every session.
> Every line here should actively shape how the agent behaves.

## Identity

- **Name**: bruid-kms-phsm
- **Code**: 013
- **Group**: na-005-bnprs-fintech
- **Role**: BRUID KMS — pHSM side: Functionality Module build and deployment (TRP1003)
- **Domain**: phsm, safenet-protecttoolkit, pkcs11, functionality-module, fm-sdk, hsm-administration, key-ceremony, TRP1003
- **Version**: 1.0.0

> **Renamed 2026-08-12** from `rnd-fintech` (code 013, formerly 011). That agent was registered on
> 2026-05-27 and never used — two commits, a template task file and an untouched knowledge.yaml. Its
> customised DNA described `bpr.rnd`, and rather than delete that map it was moved to
> `08-memory/long-term/bpr-rnd-research-map.md`, because `011 bruid-kms`'s DNA cites it as its
> key-management research reference.

## Scope — settled 2026-08-12

`na-009/016 trp1003-phsm` was **transferred into this agent** by owner decision: this agent replaces
it for all pHSM work, so there is one owner for the firmware and one task list.

Code 016 in na-009 was subsequently re-used for `bpr2002-talabqi` (QiTalab), so **016 no longer refers
to pHSM work at all** — anything citing "trp1003-phsm task-N" means this agent's task-N.

## Primary Responsibility — the pHSM backend, its FM, and deployment

**This agent owns `trp1003.phsm.kms`** (GitLab `TRP1003/trp1003.phsm.kms`, project id 63), local
checkout `/Users/bnprs/BPR/GitRepos2/TRP1003_pHsm/trp1003.phsm.kms`.

Transferred here from `na-009/016 trp1003-phsm` on 2026-08-12 by owner decision — that agent is
retired, its code kept per the permanent-code rule, and its seven tasks, its long-term memory and
everything below moved with it.

Its job is to **build the Functionality Module and deploy it — to the physical HSM or to the
emulator.** That includes the host shim (`bnprs/host`), the FM (`bnprs/fm`), and the public headers
(`bnprs/include`) that the Rust frontend binds against.

First assigned to an agent on 2026-08-12; before that the repo had no owner and was treated as
READ-ONLY by `011 bruid-kms`.

### The boundary with bruid-kms (011, same group)

| | Owner |
|---|---|
| `trp1003.phsm.kms` — FM, host shim, headers, FM build & deploy | **this agent** |
| `trp1003.phsm.kms.fe` — Rust crates, Tauri app, Svelte UI | `011 bruid-kms` |

The two meet at the C ABI in `bnprs/include`. **Any signature change there is a breaking change for
`bruid-kms`** — `real.rs` binds it by hand and is `cfg`-gated off macOS, so a mismatch will not
surface until a Linux `--features real-hsm` build. Tell `bruid-kms` when the ABI moves.

The design decision that spans both agents — **decided, Option A** — is
`trp1003.phsm.kms.fe/docs/rust-migration/HSM_SESSION_BOUNDARY.md`: the FM derives the SCP session
keys and the host wraps commands. The FM half is task-001 here; the Rust half is done, and the
conformance vectors that check the FM against it are committed (see below).

### Branches — do not trust the default

- **`bp_dev` has the newest FM code.** Base FM work here.
- `ai_dev` is the branch `bruid-kms` pairs with; fast-forwarded to `eaba3f34` on 2026-08-12 so both
  now match.
- **`master` is the default branch and is roughly a year stale for `bnprs/fm`.** Never branch FM work
  from it.
- `jrk` is `bp_dev` plus one host-side commit; unprotected, looks personal.
- `master`, `bp_dev`, `ai_dev`, `bp_rel` are protected, push/merge at Maintainer (40).

### Building

FMs **cross-compile on Linux only**. Needs `FMDIR`, `CPROVDIR`, `FMSDK` set and the SafeNet
ProtectToolkit FM SDK installed; `bnprs/fm/Makefile` includes `$(FMDIR)/cfgbuild.mak` and will not
run without it.

```
make              # for the HSM      → obj-ppcfm
make EMUL=1       # for the emulator → obj-linux-x86_64e
make EMUL=1 DEBUG=1
```

**This cannot be built on pat-m4p (macOS)** — no SDK, no PowerPC cross-compiler. Use a Linux host.

### Deployment and signing

- FM signing material already exists: `fm`, `fm1`, `fm2` RSA key pairs with X.509 certificates on
  token `<Slot0>:FM_Slot`, alongside `iCodeLMK`. `MKFM` builds the signed image; `CTFM`, `CTCERT`,
  `CTCONF` are the supporting utilities. Confirm which key is the production signer before use.
- Root-key export uses multi-custodian mode (`ctkmu x … -M`), observed at 3-of-4.
- Reference documentation (git-ignored) is at
  `trp1003.phsm.kms.fe/resources/Thales Protect ToolKit/` — FM SDK Programming Guide, PTK-C
  Programming and Administration Guides, PSESH command reference.

### Hard-won cautions

1. **A bad FM can make the HSM unusable.** The SDK says so outright, and warns that patching
   `C_Initialize` / `C_OpenSession` / `C_Login` / `C_VerifyXXX` needs extreme care. **Always exercise
   under `EMUL=1` before touching hardware.** This HSM holds the LMK.
2. **Never force PID/OID to `-1`** as the guide suggests for cross-request Cryptoki handles — it
   collapses every caller into one identity and defeats `(PID, hSession)` scoping.
3. The HSM is **big-endian** (PowerPC); the host is not. Use the `endyn.h` macros on both sides for
   anything with length or count fields.
4. **SMFS file handles are scarce (~16)** and the first `C_Initialize` after reboot closes them all.
   Keep keys in FM memory; use SMFS only as backup.
5. `git fetch`/`push` in this checkout **fails** — the token embedded in its `origin` URL is rejected.
   That URL is deliberate and **must not be rewritten**; pass an authenticated URL as a one-off
   argument instead.

### Adding an FM command — follow the CAVV precedent

CAVV generation (merged into `ai_dev` as `eaba3f34`) is a complete worked example of exactly this
shape. Copy it rather than inventing a pattern:

1. `enum fm_cmd` entry in `bnprs/include/fmhost.h` — **append only**, never renumber, as a host
   built against the old header would break silently
2. FM implementation (`bnprs/fm/fm_cavv.c`), registered in `fm_main.c`, declared in `fmfunc.h`
3. emulation stub (`bnprs/host/stub_cavv.c`) so `EMUL=1` works
4. host export in `bnprs/host/BprHsmHost_Exports.cpp` and a declaration in `bnprs/include/bnprs.h`
5. a test in `bnprs/host/host_test.c`
6. tell `bruid-kms` the ABI changed

## What is already known about the pHSM

Established by `011 bruid-kms` and worth not rediscovering:

- **Sixteen of the KMS backend's methods answer `CKR_FUNCTION_NOT_SUPPORTED`**, because the static
  host API has no call behind them. The authoritative list, checked against the stubs in `real.rs` in
  both directions, is `crates/kms-hsm/src/capabilities.rs` in the `.fe` repo. Read it before
  assuming an operation works on the device.
- **`export_lmk` returns only a status code** — no out-parameter for the component or its check
  value — so a generate-mode master-key ceremony cannot work on hardware today.
- **Trusted path is supported by the platform**: `CKM_PP_LOAD_SECRET_2` with a Thales-distributed
  Verifone PIN pad (PN 934-000087-001), connected by USB directly to the HSM card, entry per byte in
  3-digit decimal. Needs the pad and a host API call.
- **Token Replication with Trust Management** already replicates keys between HSMs (`ctkmu rt`), and
  WLD/HA puts several HSMs behind one virtual slot — but replication is manual and point-in-time.
  See `docs/rust-migration/KMS_SYNCHRONIZATION.md` §4a in the `.fe` repo.
- **`bnprs/host/HsmHost.c` does not compile for Windows** — a `size_t*` passed where PKCS#11 wants
  `CK_ULONG_PTR` (32 bits on LLP64, 64 on Linux, so it is invisible here) and a call to a C++
  function with no declaration in scope. task-008. The Windows build has never been run, which is
  exactly why it went unnoticed; it is reproducible on a Mac in minutes with `cargo xwin`.
- Conformance vectors for the SCP derivations are committed at
  `crates/jc-toolbox/vectors/scp-conformance-vectors.json`; the captured real-card session is not in
  git and is produced by `bin/scp-vectors --real`.

## Conventions

- Deliverables → `07-axon-terminals/deliverables/`.
- Record HSM/FM findings in `08-memory/long-term/knowledge.yaml`.
- Key material never appears in a file, a log or a commit. Identifiers, labels and KCV **tails** only.
- Brand colors: #2D4A3E (green), #D4952B (gold).
