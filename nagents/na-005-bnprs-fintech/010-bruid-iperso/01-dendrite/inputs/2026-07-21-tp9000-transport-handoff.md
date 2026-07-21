# INPUT → na-005/010 bruid-iperso

**Routed by:** na-100/003 rnd-cperso · **Date:** 2026-07-21 · **Priority:** MEDIUM · **Status:** OPEN
**Planner record:** rnd-cperso `task-005-tp9000-transport.yaml` (+ rnd-cperso knowledge mem-019)
**Implementation task (this agent):** `02-cell-body/planning/todo/task-002-tp9000-transport.yaml`
**Vendor spec (READ FIRST):** `bpr.cpp/docs/Specification for Nuvia TPK DLL_4 1 2 5(E)_20240708.doc`
— POINTMAN "Card Printer Standard User Library Specifications (TP9000.DLL)", rev 4.1.2.5 (2024-07-08).

## Scope — CONFIRMED (user, 2026-07-21)
This is the **iperso (instant/kiosk) transport — NOT cperso**. bruid-iperso owns it. Corroborated by the
vendor spec (TP9000.DLL is a **card printer/encoder** = an instant-issuance device) and this agent's
existing Pointman kiosk integration (input `2026-07-13-pointman-kiosk-integration-v1.3.md`).

## Why this is yours
The **Pointman TP9000 is the kiosk's card-handling hardware** — the motorized feeder that pulls a blank,
holds it at the contact station for perso, then ejects it. It is the physical transport your **kiosk
executor** (`task-001.2`) runs the SCP02 APDU perso script over. The 2026-07-13 Pointman integration input
assumed the executor would "replay the script … **over PC/SC**"; the TP9000 is the real transport — a
**vendor DLL (`TP9000.dll`) that drives the chip contacts directly, NOT through PC/SC/winscard**. This
handoff makes that transport concrete. Fits iperso (feeder-per-card, instant/counter issuance).

## The one-line ask
Add a **`perso::driver::Tp9000Channel : ICardChannel`** to the perso engine
(`bpr.cpp/src/BprCardEmv/persoengine`) so `perso-live` / the kiosk executor can drive a Pointman feeder,
selectable alongside the existing PC/SC transport. **No engine-core changes** — it drops in behind the
`ICardChannel` seam (`card.hpp:29`), exactly where `BprPcScChannel` sits today.

## Ground truth (verified 2026-07-21 — reuse, don't reinvent)
- A **partial wrapper already exists**: `bpr.cpp/src/BprPcSc/tp9k/tp9k.{h,cpp}` — class `Tp9000Card`,
  Windows-only (`LoadLibrary`+`GetProcAddress` on `TP9000.dll`). Exports:
  `CheckFeeder / Card_Insert / IC_ContactOn / IC_PowerOn / IC_Input / Card_Eject`.
  - `PatTp9000_Transmit` (via `IC_Input`) is **functional**.
  - `PatTp9000_ATR` / `PatTp9000_Open` / `PatTp9000_Close` are **stubbed / commented out** — finish these.
- The **old** BprCardQi/BprCardEmv already dispatch by slot (`PatCard_Transmit`, `BprCardQi.cpp:267`):
  `PAT_SLOT_TP9000 = -1` → feeder, `PAT_SLOT_HOST = -2` → KMS host, `>=0` → PC/SC reader. This matches
  MCES2 `BprMces2Config.xml` → `Perso/UserCardSlot` (`-1 = TP9000`). **Reuse the −1==TP9000 convention.**
- The **new persoengine has ZERO TP9000 code** — the live apps hard-construct `BprPcScChannel`
  (`apps/perso-live-visa/main.cpp:257`). That's the gap.

## What to build (detail in task-002 subtasks)
1. **Finish `Tp9000Card`** — real ATR decode; re-enable `IC_ContactOn`/`IC_PowerOn` in Open and
   `Card_Eject` in Close; distinct error codes for jam / no-card / power-on fail. Keep Windows-only.
2. **`Tp9000Channel : ICardChannel`** (`card_tp9000.{hpp,cpp}`) wrapping `Tp9000Card`:
   `transmit()` = `IC_Input` **+ the SAME 61xx/6Cxx resolution loop as `BprPcScChannel::transmit()`**
   (the vendor DLL does raw I/O — chaining is ours). Guard `PERSOENGINE_BUILD_TP9000` + `WIN32`,
   mirroring the `PERSOENGINE_BUILD_PCSC` block (`persoengine/CMakeLists.txt:41`).
3. **Transport factory** in the live apps: `--transport pcsc|tp9000` (default pcsc) → `unique_ptr<ICardChannel>`.
4. **Feeder lifecycle** for instant issuance: `Card_Insert` per card → perso stream → **read-back verify
   BEFORE eject** (GPO/READ RECORD/VERIFY PIN as in your MC/Visa proofs) → eject-good vs **divert-reject**.
5. **Bench-verify on the Windows perso host** with a real TP9000 (cannot be tested on pat-m4p — Win32 DLL).

## Vendor-spec facts to build to (from the TP9000.DLL API doc)
- **Power-on:** use `IC_PowerOnEx(cno=0, …, nMode=2)` — **EMV mode** (nMode 1=ISO / 2=EMV). The ATR comes
  back in the RX buffer (implements the wrapper's ATR stub). The current wrapper calls plain `IC_PowerOn`.
- **Transmit:** `IC_Input(cno=0, …)` is one raw APDU exchange with **no auto-chaining** — so 61xx/6Cxx
  handling is ours (mirror `BprPcScChannel`). `IC_MultiAPDU` can batch, but per-APDU is better for STORE
  DATA error localization.
- **Status:** use **`GetTPKStatus`**, not `CheckFeeder` — the spec marks CheckFeeder "Not using for TPK".
- **Sockets:** `cno` 0=Main, 1=SIM, 2/3=SAM. Feed/eject: `Card_Insert/InsertEx`, `Card_EjectEx` (Full-eject).
- **Contactless = NOT in scope (confirmed).** The RF module in this DLL rev is **Mifare block-ops only**
  (`RF_Read/Write/Authenticate/…` + `RF_PowerOnEx`/ATS) — there is **no ISO14443-4 (T=CL) APDU pipe**. So
  contact-only. If dual-interface EMV perso is ever needed, escalate to Pointman for a newer DLL.

## Constraints / gotchas
- **Windows-only.** `TP9000.dll` is a Win32 DLL; this transport can't build/run on pat-m4p (pcsclite).
  Keep the CMake option default OFF so Mac builds + unit tests stay hardware-free.
- **No engine-core edits** — `tlv/profile/sequencer/oda` untouched; only a new `ICardChannel` + app wiring.
- **PCI unchanged** — synthetic/test PANs only, never log TRACK/PIN/CVV, DEK-wrapped key DGIs only; the
  transport does not touch the data path.
- A **reject/divert path** must exist so a failed card is never ejected as a good card.

## Open questions (see task-005; two resolved 2026-07-21)
1. ~~iperso vs cperso~~ — **RESOLVED: iperso** (user + vendor spec).
2. `TP9000.dll` **bitness + version** on the perso host (x86/x64) — must match the host process (spec is
   rev 4.1.2.5; confirm the deployed DLL). **OPEN.**
3. ~~Contactless?~~ — **RESOLVED: contact-only** (RF module is Mifare-block-only, no T=CL APDU pipe).
4. **T=0 vs T=1** and max APDU/RX buffer through `IC_Input` — use `IC_PowerOnEx nMode=2` (EMV) for protocol
   negotiation; affects 61xx/6Cxx handling + extended length. **OPEN.**

## Cross-refs
- rnd-cperso `task-005-tp9000-transport.yaml` (canonical design) + knowledge mem-019.
- This agent `task-001` (kiosk executor `task-001.2` — the TP9000 is its transport) + input
  `2026-07-13-pointman-kiosk-integration-v1.3.md` (Pointman = kiosk hardware vendor).
- `bpr.cpp/src/BprPcSc/tp9k/tp9k.{h,cpp}` (wrapper) · `persoengine/card.hpp` (seam) ·
  `card_bprpcsc.{hpp,cpp}` (the PC/SC sibling to mirror) · `CMakeLists.txt:41` (option block to mirror).
