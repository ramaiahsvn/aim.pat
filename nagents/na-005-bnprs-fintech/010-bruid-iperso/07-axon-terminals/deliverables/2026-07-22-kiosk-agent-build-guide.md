# Kiosk Agent — Build Guide (remote-APDU iPerso)

**For:** the Kiosk team · **From:** na-005/010 bruid-iperso · **Date:** 2026-07-22 · **Status:** UAT

## The model

iPerso now runs like cPerso, but the **card is remote**. The **Bureau** (a trusted server with the
on-prem HSM + perso engine) does dPrep and drives the *entire* personalization LIVE. Your **Kiosk agent**
is a thin, secure **relay**: it holds no keys, no scripts, no data at rest — it just passes APDUs between
the Bureau and the card on its local reader/feeder.

```
   KIOSK AGENT (you build this)                 BUREAU (pat-m4p for UAT; real bureau later)
   ┌───────────────────────────┐   NDJSON/TCP   ┌──────────────────────────────────────────┐
   │ 1. connect out + auth      │◄──────────────►│ perso-bureau : engine + HSM + keys        │
   │ 2. submit perso request    │   (TLS in prod)│  - dPrep (decode embossing / DPI)          │
   │ 3. open local card         │                │  - ISD SCP02, INSTALL, STORE DATA, verify  │
   │ 4. relay each APDU ↔ card  │                │  - decides eject vs reject                 │
   │ 5. eject / reject          │                └──────────────────────────────────────────┘
   └───────────────────────────┘
        │ local card I/O
        ▼  TP9000 v2 feeder  OR  PC/SC reader
       [ the card ]
```

**You provide:** the relay agent + the local card channel (TP9000 v2 or PC/SC).
**Bureau provides:** all crypto, keys, and the APDU stream. Keys are provided to the Bureau separately —
never to the Kiosk.

## Transport & protocol

- **Wire:** newline-delimited JSON (**NDJSON**) over a TCP socket — one JSON object per line (`\n`).
  Trivial to implement in C#/.NET, Java, or Python.
- **Direction:** the Kiosk **connects out** to the Bureau (Kiosk may be behind NAT). UAT Bureau =
  `pat-m4p-ip:9099`.
- **Security:** **UAT** = plain TCP + a shared `token` in the `hello`. **PROD** = TLS 1.2+ with **mutual
  auth** (client fleet cert — same pattern as the existing `k3_fleet_pfx` → `kms.bnprs.ai`). Design the
  socket layer so TLS is a drop-in (wrap the stream); do not hardcode plaintext.
- **Hex:** all APDUs are uppercase hex strings (command incl. Lc/Le; response = data ‖ SW1 ‖ SW2).

### Message flow (each line is one JSON object with a `type`)

| # | Direction | `type` | Fields | Kiosk action |
|---|-----------|--------|--------|--------------|
| 1 | K → B | `hello` | `token`, `kioskId`, `agentVersion`, `capabilities:["tp9000","pcsc"]` | connect + authenticate |
| 2 | B → K | `hello_ack` | `protocol`, `server`, `sessionId` | proceed |
| 3 | K → B | `perso_request` | `channel:"iperso"`, `transport:"tp9000"\|"pcsc"`, `inputType:"dpi"\|"embossing"`, `inputB64` | submit the job + input |
| 4 | B → K | `card_open` | `transport` | open the LOCAL card channel (feed + power on) |
| 5 | K → B | `card_opened` \| `card_error` | `atr` (hex) \| `detail` | report ATR or failure |
| 6 | B → K | `apdu` | `seq` (int), `capdu` (hex) | **transmit to the card, get the response** |
| 7 | K → B | `apdu_response` \| `apdu_error` | `seq`, `rapdu` (hex) \| `detail` | return the card's response |
| … | | | | (6–7 repeat for the whole perso stream) |
| 8 | B → K | `card_finish` | `disposition:"eject"\|"reject"` | eject a good card / divert a failed one |
| 9 | K → B | `card_finished` | `ok` | confirm |
| 10 | B → K | `result` | `status:"ok"\|"fail"`, `detail` | show outcome; close |

Any side may send `{"type":"error","detail":"..."}` and close on a fatal problem.

## What your agent must do

1. **Connect + `hello`** with the token (UAT) / present the client cert (PROD). Wait for `hello_ack`.
2. **Send `perso_request`** with the chosen `transport` and the base64 of the issuer input (the DPI XML for
   iPerso, or the embossing file). The Bureau decodes + decrypts it (keys are Bureau-side).
3. **On `card_open`:** open your LOCAL card channel and return the `atr`:
   - **TP9000 v2 feeder:** load `TP9000.dll` (64-bit — matches the kiosk DLL), feed a blank, contacts on,
     EMV cold reset (`IC_PowerOnEx nMode=2`), read the ATR. (Reference: `tp9k_v2` / `Tp9000Channel` in
     bpr.cpp — same call sequence.)
   - **PC/SC:** connect to the reader, `SCardStatus` for the ATR.
4. **On each `apdu`:** transmit `capdu` to the card and return the exact response as `rapdu`.
   - **CRITICAL — resolve chaining locally.** Handle `61xx` (GET RESPONSE `00 C0 00 00 xx`) and `6Cxx`
     (re-issue with Le = xx) on the Kiosk so you return the **final** data ‖ SW. The Bureau relays raw and
     does NOT chain. (Both `BprPcScChannel` and `Tp9000Channel` in bpr.cpp already do exactly this — copy
     that loop.)
   - Preserve `seq` in the reply.
5. **On `card_finish`:** `eject` (good → stacker/front) or `reject` (divert to the reject bin —
   `Card_Control 0x36`). Confirm with `card_finished`.
6. **On `result`:** display success/failure to the operator.

## Error & recovery rules

- A dropped connection mid-session may leave a **half-personalized card**. The Bureau only finalizes
  (SET STATUS → SECURED) as the **last** step after a passing GPO, so a drop before that leaves an
  un-secured card that can be re-attempted; a drop after leaves a card to **reject**. If you lose the link
  after `card_open` and before `result`, **reject the card** and let the operator retry.
- Return `apdu_error`/`card_error` with a `detail` on any local failure — never fabricate a `9000`.
- Never log full PAN / Track / CVV / PIN. APDU payloads are sensitive (SAD) — treat the whole channel as
  PCI data: TLS in prod, no persistence, no plaintext logs of card data.

## Build steps (Kiosk agent)

1. **Pick your stack** — C#/.NET is fine (and matches the perso-host tooling). Java/Python also work; the
   protocol is language-neutral.
2. **Socket + NDJSON layer:** connect to the Bureau; read/write one JSON object per line. Make the stream
   pluggable so PROD can wrap it in TLS (with a client cert).
3. **Local card channel** — implement both, selected by `transport`:
   - TP9000 v2 (feeder): P/Invoke `TP9000.dll` — `GetTPKStatus`, `Card_Insert`, `IC_ContactOn`,
     `IC_PowerOnEx(nMode=2)`, `IC_Input`, `Card_EjectEx`, `Card_Control(0x36)`. Match the DLL bitness
     (64-bit). Reference impl: `bpr.cpp/src/BprPcSc/tp9k/tp9k_v2.*`.
   - PC/SC: `SCardConnect` / `SCardTransmit` / `SCardStatus` (WinSCard on Windows; PCSC-lite elsewhere).
   - Both must resolve `61xx`/`6Cxx` locally (see step 4 above).
4. **State machine:** hello → perso_request → (card_open→opened) → loop(apdu↔apdu_response) → card_finish →
   result. Keep it single-session, single-card for UAT.
5. **Test against the UAT Bureau** on pat-m4p: run `perso-bureau <port> <token>` there; point your agent at
   its IP. The Bureau currently drives a **read-only SELECT sequence** (proves the relay) — you should see
   two `apdu` messages and a `result`. Full live perso turns on next (same protocol, more APDUs).
6. **PROD:** switch the socket to TLS + present the fleet client cert; the Bureau enforces mutual auth.

## Reference

- Bureau: `bpr.cpp/src/BprCardEmv/persoengine/apps/perso-bureau/main.cpp` (protocol authority + `RemoteChannel`).
- Local card channels to mirror: `bpr.cpp/src/BprPcSc/tp9k/tp9k_v2.*` (TP9000 v2) and
  `persoengine/src/card_bprpcsc.cpp` (PC/SC) — both show the exact ATR + transmit + 61/6C chaining logic.
- A minimal mock kiosk (Python, canned responses) used to validate the protocol is available on request.
- iPerso architecture + this model: bruid-iperso task-003 (remote-APDU) + knowledge.
