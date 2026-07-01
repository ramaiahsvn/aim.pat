---
name: EMV Perso Engine — C++ Architecture / Module Design
description: task-002.2 deliverable — architecture for the standalone C++ EMV+Calypso personalization engine (PC/SC + SoftHSM, CMake). Grounded in the 2026-07-01 Resources drop (MC+Visa profiles, Gemalto/TechTrex traces, SCP02).
type: project
---

> **task-002.2 deliverable** (design). Supersedes the module sketch in [[emv-engine-plan]].
> Grounded in [[perso-resources-inventory]] (ground-truth profiles + APDU traces delivered 2026-07-01)
> and the existing Thales stack in `hsm-integration-analysis.md` / `reverse-engineering.md`.
> Guardrails: no key VALUES here — labels/IDs only. Real PANs/keys stay in git-ignored `Resources/`.

## 1. Goal & scope

Build a **standalone C++ card personalization engine** that replaces the proprietary Thales
`.per` bytecode + Operas/Interpreter stack with an open, auditable implementation. It:

1. Reads an **embossing file** (Tri-Badge PURE V3.0) → per-card records.
2. Loads an issuer **card profile** (MC ADDONS XML / Visa VPA XML) → the EMV tag/DGI template.
3. Derives per-card keys + crypto via an **HSM** (SoftHSM for dev/test, real HSM later).
4. Encodes **BER-TLV / DGI** data and drives the card over **PC/SC** with a full
   **GlobalPlatform SCP02** perso sequence (SELECT → INIT-UPDATE → EXT-AUTH → STORE DATA…).
5. Verifies (read-back) and emits a structured **audit log**.

**In scope:** EMV payment (Visa VSDC/qVSDC, Mastercard M/Chip) + Calypso ticketing (TRANSLINK key
scheme, from the existing hierarchy). **Out of scope (v1):** physical card transport/embossing
machine control, MIFARE, Thales binary compatibility.

### Non-goals
- Not a drop-in for MCES2/SPI4MLB2 — decoupled by design (decision 2026-05-30).
- Not linking any Thales proprietary DLL — clean-room, standards-based.

## 2. Locked decisions

| Axis | Decision |
|---|---|
| Platform | **Cross-platform CMake** (C++17); primary Linux, buildable on Windows/macOS |
| HSM | **SoftHSM2 via PKCS#11** for dev/test, behind an `IHsmClient` interface; swap to real HSM later |
| Card I/O | **PC/SC** (`pcsclite` on Linux/macOS, WinSCard on Windows) via an `ICardChannel` interface |
| Card types | **Both** — EMV payment + Calypso; profile/key scheme abstracted |
| Secure channel | **GlobalPlatform SCP02** (confirmed from Gemalto trace); SCP03 behind the same interface later |
| Integration | Standalone CLI + library (`libpersoengine`) |

## 3. Layered architecture

```
              ┌─────────────────────────────────────────────┐
   CLI  ─────▶│  perso-cli  (argparse, run one embossing file)│
              └───────────────┬─────────────────────────────┘
                              ▼
        ┌───────────────────────────────────────────────────────┐
        │  PersoSequencer   (orchestration; audit; error recovery)│
        └───┬───────────┬───────────┬───────────┬────────────────┘
            ▼           ▼           ▼           ▼
   ┌────────────┐ ┌───────────┐ ┌─────────┐ ┌──────────────┐
   │ Profile    │ │ Embossing │ │ DglTlv  │ │ GpSecureChan │
   │ Model+Load │ │ Parser    │ │ Encoder │ │  (SCP02)     │
   └────────────┘ └───────────┘ └─────────┘ └──────┬───────┘
            ▲                          ▲            │
            │                          │            ▼
      ┌─────┴───────┐         ┌────────┴───────┐ ┌──────────────┐
      │ IHsmClient  │         │  Emv/Calypso   │ │ ICardChannel │
      │ (PKCS#11)   │         │  KeyDerivation │ │  (PC/SC)     │
      └─────────────┘         └────────────────┘ └──────────────┘
```

Two **hardware-abstraction interfaces** (`IHsmClient`, `ICardChannel`) are the only seams that
touch the outside world — everything else is pure/testable.

## 4. Modules & interfaces (C++17 sketch)

### 4.1 `emv::tlv` — BER-TLV + DGI encoder
Pure, dependency-free. The foundation everything builds on.
```cpp
namespace emv::tlv {
  using Tag   = uint32_t;              // 1–4 byte tag, e.g. 0x9F07
  using Bytes = std::vector<uint8_t>;

  Bytes encode_tag(Tag);              // canonical multi-byte tag
  Bytes encode_len(size_t);           // short/long BER length
  Bytes tlv(Tag, const Bytes& value); // one TLV
  Bytes concat(std::initializer_list<Bytes>);

  struct Dgi { uint16_t id; Bytes data; };          // e.g. {0x9115, ...}
  Bytes encode_dgi(const Dgi&);                      // 2-byte id + len + data
  std::vector<Dgi> group_by_dgi(const CardProfile&); // profile tags -> DGIs
}
```
DGI grouping is driven directly by the Visa VPA `dgi=` attributes (9115/9117 seen) and, for
Mastercard, the M/Chip DGI convention (0101/0201/8000-series keys, etc.).

### 4.2 `perso::profile` — card profile model + loaders
One in-memory model, two vendor loaders (strategy pattern).
```cpp
struct ProfileTag { emv::tlv::Tag tag; std::optional<uint16_t> dgi; std::string name; Bytes value; };
struct KeySlot   { std::string label; KeyType type; std::optional<uint8_t> version; }; // NO key values
struct CardProfile {
  Scheme scheme;                 // Visa | Mastercard | Calypso
  Bytes  aid;                    // 4F / DF Name (84)
  std::vector<ProfileTag> tags;  // populated EMV data
  std::vector<KeySlot>    keys;  // key labels/versions only
};
struct IProfileLoader { virtual CardProfile load(const std::filesystem::path&) = 0; };
struct VisaVpaLoader   : IProfileLoader { /* config>template>tagelement, reads dgi=  */ };
struct McAddonsLoader  : IProfileLoader { /* ADDONS>WORKSHEET>ELEM (fci/internal/record*) */ };
```
Guardrail: loaders **must reject** any profile that carries populated key values (both delivered
profiles ship empty key fields — enforce that invariant).

### 4.3 `perso::embossing` — Tri-Badge PURE V3.0 parser
```cpp
struct EmbossingRecord { std::string pan, name, expiry, linkId; std::map<int,std::string> fields; };
class EmbossingParser {
  std::vector<EmbossingRecord> parse(std::istream&);   // fixed-length, LF-delimited
};
```
- Fixed-length records; **actual width 21,228 chars** (⚠ spec V3.0 says ~21,157 — reconcile the
  +71 delta against the docx before trusting field offsets; treat width as a validated constant).
- Co-badge MC+PURE+QI records grouped by shared `LinkId` (UUID) — same as `task-001` DataPrep.
- Sensitive: PAN/PIN/track — test data only; never logged in clear.

### 4.4 `hsm::IHsmClient` — crypto abstraction (PKCS#11 → SoftHSM)
```cpp
struct IHsmClient {
  virtual Bytes derive_udk(std::string_view imkLabel, const Bytes& pan, const Bytes& psn) = 0; // EMV Opt.A
  virtual Bytes encrypt_under_kek(std::string_view kekLabel, const Bytes& clearKey)       = 0;
  virtual Bytes kcv(const Bytes& key)                                                      = 0; // 3-byte KCV
  virtual Bytes mac_scp02(const Bytes& sessionMac, const Bytes& data)                      = 0;
  virtual RsaKeyPair gen_icc_rsa(int modulusBits)                                          = 0; // 1024/1152
  virtual Bytes sign_sda(std::string_view issuerKeyLabel, const Bytes& staticData)         = 0; // tag 93
  virtual Bytes gen_icc_cert(const IccCsr&)                                                = 0; // tag 9F46/…
};
class SoftHsmClient : public IHsmClient { /* PKCS#11 session; keys referenced by CKA_LABEL */ };
```
Maps 1:1 onto the Operas macro operations documented in `hsm-integration-analysis.md`
(`BatchDerivation`, `ExportDESKey`, `CalculateKCV`, `TranslateDESKeyBlock`). Keys addressed by
**label** only (never value) — same discipline as the KMS labels (KAB/KTR/CI/…).

### 4.5 `card::ICardChannel` — PC/SC transport
```cpp
struct Apdu     { uint8_t cla,ins,p1,p2; Bytes data; std::optional<uint8_t> le; };
struct Response { Bytes data; uint16_t sw; bool ok() const { return sw==0x9000; } };
struct ICardChannel {
  virtual Atr     connect() = 0;
  virtual Response transmit(const Apdu&) = 0;
  virtual void    disconnect() = 0;
};
class PcscChannel : public ICardChannel { /* SCardConnect/Transmit/Disconnect */ };
```
Auto-handles `61xx` (GET RESPONSE) / `6Cxx` (wrong Le) chaining, as seen in the Gemalto trace
(`80500000` → `611C` → `80C00000`).

### 4.6 `gp::SecureChannel` — GlobalPlatform SCP02
```cpp
class ScpSession {
  ScpSession(ICardChannel&, IHsmClient&);
  void open(const Bytes& isdAid, uint8_t keyVersion, SecurityLevel);  // INIT-UPDATE + EXT-AUTH
  Response store_data(uint8_t p1, uint8_t p2, const Bytes& block);    // wraps + MACs
  void install_for_load_and_make(const Bytes& load, const Bytes& inst);
  void delete_object(const Bytes& aid);
};
```
Implements exactly the observed SCP02 flow: INITIALIZE UPDATE (host challenge) → GET RESPONSE (28-B
= key-div-data ∥ key-info ∥ card-challenge ∥ card-cryptogram) → verify card cryptogram → EXTERNAL
AUTHENTICATE (host cryptogram ∥ C-MAC). Session keys derived in the HSM; C-MAC/C-ENC applied per
security level.

### 4.7 `perso::Sequencer` — orchestration (the heart)
Drives the **exact sequence recovered from the Gemalto trace**:
```
per card:
  1. connect() → ATR
  2. SELECT Card Manager (00A4 0400)
  3. ScpSession.open(ISD)                    // 8050 / 80C0 / 8482  (SCP02)
  4. DELETE stale instances (80E4 0000)      // ×N  — idempotent cleanup
  5. INSTALL [for load & make selectable]    // 80E6 0C00 ×N — instantiate applets
  6. for each applet in profile:
       SELECT applet (00A4 0400 <AID>)
       ScpSession.open(applet)               // re-auth per applet
       for each DGI block:
         STORE DATA (80E2 P1 P2 …)           // P2 = 0x00..0x2B sequential block index
                                             // P1: 0x00 more · 0x60 enc/key block · 0x80 last
  7. (optional) read-back verify tags (5A/57/5F24/8C/8D/82/94/…)
  8. disconnect(); emit audit record
```
Error recovery: on any non-9000 SW → abort card, log tag context + SW, continue batch (configurable
stop-on-error). Never retry a partially-personalised card silently.

### 4.8 `audit` — structured logging
JSON-lines per card: `{linkId, aid, scheme, dgiCount, result, sw?, durationMs}`. **No PAN/PIN/keys**
in logs (mask PAN to first6+last4). Mirrors the OP_MakeAudit responsibility of the old stack.

## 5. Data flow

```
embossing file ─▶ EmbossingParser ─▶ EmbossingRecord(s)
                                         │  (LinkId groups co-badge)
card profile ──▶ ProfileLoader ─▶ CardProfile (tags + DGI map + key labels)
                                         │
        merge(record, profile) ─▶ resolved TLVs (PAN/expiry/name filled from embossing)
                                         │
                DgiTlvEncoder ─▶ ordered DGI blocks
                                         │      keys ▶ IHsmClient (derive/encrypt/KCV/sign)
                       PersoSequencer ─▶ GP SCP02 STORE DATA stream ─▶ ICardChannel ─▶ card
                                         │
                                     read-back verify ─▶ audit
```

## 6. Project layout & build (CMake)

```
persoengine/
  CMakeLists.txt
  include/persoengine/{tlv,profile,embossing,hsm,card,gp,sequencer,audit}.hpp
  src/…                              # one .cpp per module
  apps/perso-cli/main.cpp
  third_party/                       # pcsclite, PKCS#11 headers (SoftHSM), pugixml, GoogleTest
  tests/                             # unit + trace-replay integration
  profiles/                          # sample MC/Visa profiles (NO real data)
```
Deps (all portable, permissive): **pugixml** (profile XML), **PKCS#11** headers + SoftHSM2 (HSM),
**pcsclite/WinSCard** (card), **GoogleTest** (tests), **spdlog/nlohmann-json** (audit). No Thales code.

## 7. Testing strategy
- **Unit:** TLV/DGI vectors; SCP02 session-key + cryptogram against a known reference session;
  EMV Option-A UDK against a public test vector (via `SoftHsmClient`).
- **Trace-replay integration:** feed the **Gemalto** and **TechTrex** traces into a `MockCardChannel`
  that asserts the emitted APDU sequence matches the recorded one (block counts, P1/P2 progression,
  Lc). This is the acceptance oracle — the engine must reproduce the observed sequence.
- **Loopback:** SoftHSM + a PC/SC test card (or vsmartcard/virtualsmartcard) for end-to-end.

## 8. Risks / open items
- **Embossing width delta (+71)** — must reconcile field offsets vs docx before the parser is trusted.
- **Key derivation profiles** — EMV Option A confirmed for payment; **Calypso** key scheme (CI/TP/TV/
  TS/TR/TD from the TRANSLINK hierarchy) needs its own derivation path in `IHsmClient` — design it
  behind the same interface but validate separately.
- **STORE DATA P1=0x60 blocks** — confirm semantics (encrypted key/DGI vs proprietary) by decoding a
  few from the trace before finalising the GP module.
- **Test keys / KCVs** (task-001.3) and **INTERPRETER manual** (task-001.4) still outstanding — not
  blocking the design, but needed for realistic end-to-end vectors.

## 9. Implementation roadmap → feeds task-002.3

| Phase | Modules | Exit criteria |
|---|---|---|
| P1 | `tlv` + `profile` loaders | Both delivered profiles parse; DGIs round-trip; unit vectors pass |
| P2 | `embossing` parser | Sample 3-record file parses w/ zero warnings; LinkId grouping correct |
| P3 | `hsm` (SoftHSM) | UDK/KCV/SCP02 session keys match reference vectors |
| P4 | `card` + `gp` (SCP02) | Trace-replay: emitted APDUs == Gemalto sequence |
| P5 | `sequencer` + `audit` | End-to-end on SoftHSM + test card; read-back verifies EMV tags |
| P6 | Calypso key path + real-HSM adapter | Calypso card personalises; HSM swap validated |

Order chosen so each phase is independently testable and the two hardware seams (`IHsmClient`,
`ICardChannel`) are the last things exercised against real devices.
```
