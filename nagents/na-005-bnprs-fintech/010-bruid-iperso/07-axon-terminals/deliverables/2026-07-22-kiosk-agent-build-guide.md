# Kiosk Agent — Integration & Trigger Guide (remote-APDU iPerso)

**For:** the Kiosk team · **From:** na-005/010 bruid-iperso · **Date:** 2026-07-22 (rev 2) · **Status:** UAT

> **Update (rev 2):** BNPRS builds and ships the **Kiosk Agent** (`perso-kiosk-agent`, C++). The kiosk team
> does **not** implement the perso protocol or the card I/O — the agent does all of that. You only need to
> **(1) run the agent** in the background and **(2) trigger a session** over its local endpoint, passing the
> encrypted DPI + the kiosk's hardware details.

## The picture

```
  KIOSK MACHINE (Windows)                                   BUREAU (pat-m4p for UAT; real bureau later)
  ┌───────────────────────────────────────────┐            ┌──────────────────────────────────────────┐
  │ your kiosk software                         │            │ perso-bureau: engine + HSM + keys          │
  │        │ (1) TRIGGER: 127.0.0.1:9098         │            │  dPrep, SCP02, INSTALL, STORE DATA, verify │
  │        ▼   JSON { dpiB64, hardwareId, ... }  │            └──────────────────────────────────────────┘
  │  perso-kiosk-agent  (BNPRS-built, background)│◄── NDJSON/TCP ──►  (agent connects OUT to the bureau)
  │        │ relays APDUs                         │   (TLS in prod)
  │        ▼ local card: TP9000 v2 / PC/SC        │
  │      [ the card ]                             │
  └───────────────────────────────────────────┘
```

The agent is a thin relay: it holds **no keys, no script, no data at rest**. All crypto + keys live at the
Bureau (keys are provided to the Bureau separately — never to the kiosk).

## 1. Run the agent (background service)

```
perso-kiosk-agent --bureau-host <bureau-ip> --bureau-port 9099 --token <uat-token> --listen 9098
```
- Runs in the foreground listening on `127.0.0.1:9098` — deploy it as a **Windows service** / background
  process (auto-start, auto-restart). It connects OUT to the Bureau per session, so the kiosk can sit
  behind NAT; only outbound to the Bureau is needed.
- Bitness: 64-bit (matches the kiosk `TP9000.dll`). `TP9000.dll` must be next to the exe (for `--transport
  tp9000`). PC/SC needs no extra DLL.
- **UAT** uses `--token`; **PROD** replaces it with a TLS client fleet cert (mutual auth) — same
  `k3_fleet_pfx` pattern as `kms.bnprs.ai`. (The Bureau enforces it.)

## 2. Trigger a session (what your software does)

Open a TCP connection to `127.0.0.1:9098`, send **one JSON object + `\n`**, read **one JSON result + `\n`**,
close. That's the whole integration.

### Request
```json
{ "dpiB64":     "<base64 of the ENCRYPTED DPI RequestPerso XML>",
  "hardwareId": "KIOSK-DXB-014",
  "transport":  "tp9000",
  "inputType":  "dpi",
  "hardware":   { "serial":"TP9K-88231", "model":"Pointman TP9000", "os":"Win11", "location":"DXB-T1" } }
```
- `dpiB64` — the encrypted DPI as you received it. The Bureau decrypts it (keys are Bureau-side); **the
  kiosk never sees the DEK**.
- `hardwareId` / `hardware` — the kiosk's unique identity + details (used for auth/audit at the Bureau).
- `transport` — `tp9000` (feeder) or `pcsc` (reader). `inputType` — `dpi` (or `embossing`).

### Result
```json
{ "status": "ok", "detail": "...", "atr": "3BFE13...", "bureau": { ...full bureau result... } }
```
`status` is `ok` or `fail`; on failure `detail` explains (auth, card_open, apdu error, rejected, etc.).

### Example (any language; here C#-ish and shell)
```csharp
using var tcp = new TcpClient("127.0.0.1", 9098);
using var ns  = tcp.GetStream();
var req = JsonSerializer.Serialize(new { dpiB64, hardwareId="KIOSK-DXB-014", transport="tp9000", inputType="dpi" }) + "\n";
ns.Write(Encoding.UTF8.GetBytes(req));
string result = new StreamReader(ns).ReadLine();   // one JSON line
```
```bash
printf '{"dpiB64":"...","hardwareId":"KIOSK-DXB-014","transport":"tp9000","inputType":"dpi"}\n' | nc 127.0.0.1 9098
```

A ready-to-run reference client (`mock_kiosk.py` shows the same trigger shape) is in this folder.

## What the agent does for you (so you don't have to)

- Connects to the Bureau, authenticates, submits your DPI + hardware details.
- Opens the local card channel (TP9000 v2 feed + EMV cold reset, or PC/SC connect) on the Bureau's cue.
- Relays every APDU to the card and **resolves 61xx/6Cxx locally**.
- Ejects a good card / diverts a failed one to the reject bin, on the Bureau's instruction.
- Returns the final result to your trigger call.

## Your responsibilities

1. **Deploy + keep the agent running** (background/service; auto-restart). One session (one card) at a time.
2. **Trigger** with the encrypted DPI + hardware details; show the operator the `status`.
3. **Feed/collect cards** at the TP9000; the agent drives the chip. (If a session fails, the agent rejects
   the card — retry with a fresh trigger.)
4. **Network:** allow outbound from the agent to the Bureau; in PROD install the kiosk fleet cert.
5. Never log the `dpiB64` or any card data — treat the trigger payload + results as PCI-sensitive.

## Reference

- Agent: `bpr.cpp/src/BprCardEmv/persoengine/apps/perso-kiosk-agent/main.cpp` (BNPRS-built).
- Bureau: `.../apps/perso-bureau/main.cpp`. Shared wire: `.../apps/common/ndjson_conn.hpp`.
- Reference trigger client: `mock_kiosk.py` (this folder).
- Model + status: bruid-iperso task-003 (remote-APDU) + knowledge mem-004.
