# INPUT → na-005/010 bruid-iperso

**Routed by:** na-100/003 rnd-cperso · **Date:** 2026-07-21 · **Priority:** MEDIUM · **Status:** OPEN
**Planner record:** rnd-cperso `task-005-tp9000-transport.yaml` (+ rnd-cperso knowledge mem-019)
**Implementation task (this agent):** `02-cell-body/planning/todo/task-002-tp9000-transport.yaml`

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

## Constraints / gotchas
- **Windows-only.** `TP9000.dll` is a Win32 DLL; this transport can't build/run on pat-m4p (pcsclite).
  Keep the CMake option default OFF so Mac builds + unit tests stay hardware-free.
- **No engine-core edits** — `tlv/profile/sequencer/oda` untouched; only a new `ICardChannel` + app wiring.
- **PCI unchanged** — synthetic/test PANs only, never log TRACK/PIN/CVV, DEK-wrapped key DGIs only; the
  transport does not touch the data path.
- A **reject/divert path** must exist so a failed card is never ejected as a good card.

## Open questions (answer before build — see task-005 open_questions)
1. Target flow: **instant/counter (iperso, feeder-per-card)** vs in-bureau (cperso) using the TP9000 as its
   reader? Confirms this is iperso's.
2. `TP9000.dll` **bitness + version** on the perso host (x86/x64) — must match the host process.
3. **Contactless?** The wrapper is contact-only (`IC_*`). If dual-interface perso is needed, get the vendor CL API.
4. **T=0 vs T=1** and max APDU/RX buffer through `IC_Input` — affects 61xx/6Cxx handling + extended length.

## Cross-refs
- rnd-cperso `task-005-tp9000-transport.yaml` (canonical design) + knowledge mem-019.
- This agent `task-001` (kiosk executor `task-001.2` — the TP9000 is its transport) + input
  `2026-07-13-pointman-kiosk-integration-v1.3.md` (Pointman = kiosk hardware vendor).
- `bpr.cpp/src/BprPcSc/tp9k/tp9k.{h,cpp}` (wrapper) · `persoengine/card.hpp` (seam) ·
  `card_bprpcsc.{hpp,cpp}` (the PC/SC sibling to mirror) · `CMakeLists.txt:41` (option block to mirror).
