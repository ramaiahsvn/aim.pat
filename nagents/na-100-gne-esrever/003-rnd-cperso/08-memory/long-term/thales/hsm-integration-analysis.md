# Thales Operas HSM Integration Analysis

**Project:** trp1002.cperso.thales
**Date:** 2026-03-18
**Purpose:** Card Personalization System — Thales Operas HSM integration with MCES2 (Muhlbauer) perso machine

---

## 1. Architecture Overview

```
┌───────────────────────────────────────────────────────────────┐
│  MCES2 Host (Muhlbauer Perso Machine)                         │
│      │                                                        │
│      ▼                                                        │
│  ISPI4MLB2.dll (C# .NET 4.6) ← Custom bridge code            │
│      │  P/Invoke calls:                                       │
│      │  - DLL_RegisterCB()                                    │
│      │  - DLL_Initialize()                                    │
│      │  - DLL_Execute()                                       │
│      │  - DLL_Terminate()                                     │
│      │  - DLL_GetAuditFields()                                │
│      ▼                                                        │
│  SPI4MLB2.dll (Native C++, v1.0.0.1) ← Thales proprietary    │
│      │                                                        │
│      ▼                                                        │
│  Interpreter.dll (v7.22.3.9) ← Thales script VM              │
│      │  Executes .per bytecode scripts                        │
│      │                                                        │
│      ▼                                                        │
│  ┌────────────────────────────────────────────────────┐       │
│  │ Operas XOtm.exe (TCP 127.0.0.1:12345)             │       │
│  │    │                                               │       │
│  │    ▼                                               │       │
│  │  OP_GenericCrypto.dll → GenericCrypto.ini (macros)  │       │
│  │    │                                               │       │
│  │    ▼                                               │       │
│  │  KMS (kmsapipc.dll → 172.17.0.11:3500)            │       │
│  │    │                                               │       │
│  │    ▼                                               │       │
│  │  SLBCryptoAPI.dll + UPSIaccess.dll                 │       │
│  │    │                                               │       │
│  │    ▼                                               │       │
│  │  ═══════ HSM HARDWARE ═══════                      │       │
│  └────────────────────────────────────────────────────┘       │
│                                                               │
│  Card Reader (Contact / Contactless)                          │
│      ▲  APDU commands via SCPM callbacks                      │
│      │                                                        │
│  Physical Smart Card                                          │
└───────────────────────────────────────────────────────────────┘
```

---

## 2. Component Inventory

### 2.1 Custom Code (Project-Specific)

| Component | Path | Description |
|---|---|---|
| ISPI4MLB2.dll (C#) | `ISPI4MLB2/ISPI4MLB2/` | Bridge between MCES2 and SPI4MLB2 |
| GenericCrypto.ini | `Operas/GenericCrypto.ini` | HSM crypto macro definitions (key operations) |
| .per scripts | Compiled bytecode | Card personalization scripts (not in source) |

### 2.2 Thales Proprietary (Not Modifiable)

| Component | Version | Description |
|---|---|---|
| SPI4MLB2.dll | 1.0.0.1 | Perso engine (native C++, MSVC6/MFC) |
| Interpreter.dll | 7.22.3.9 | Script VM — 358 exports (56 CR_*, 144 SPI_*, 158 IT_*) |
| XOtm.exe | — | Operas HSM server process |
| OP_GenericCrypto.dll | — | Operas crypto plugin |
| OP_Perso.dll | — | Operas perso plugin |
| OP_Transform.dll | — | Data transformation plugin |
| OP_Sleep.dll | — | Echo/health check plugin |
| OP_Tracer.dll | — | Trace logging plugin |
| OP_VISB.dll | — | TLV processing plugin |
| OP_MakeAudit.dll | — | Audit trail plugin |
| SLBCryptoAPI.dll | — | Thales crypto API (1.1 MB) |
| UPSIaccess.dll | — | Unified Platform for Secure Issuance (1.1 MB) |
| kmsapipc.dll | — | KMS client library (488 KB) |

---

## 3. HSM Communication Flow

### 3.1 Initialization Sequence

```
1. ISPI4MLB2 → InitINIAndTrace()
       Load config from C:\SPI4MLB2\ISPI4MLB2.ini

2. ISPI4MLB2 → DLL_RegisterCB(22 callbacks)
       Register SCPM callback functions into SPI4MLB2.dll

3. ISPI4MLB2 → DLL_Initialize(firData)
       Send card FIR data to start perso session
       SPI4MLB2.dll internally:
         - Loads Interpreter.dll
         - Verifies license
         - Starts TCP services
         - Connects to Operas XOtm.exe (127.0.0.1:12345)
         - Sends "COMMAND SETNAME Interpreter.dll"
         - Sends "ECHO 12345678" (health check, 5s timeout)

4. Operas XOtm.exe starts:
       - Loads OP_GenericCrypto.dll (→ GenericCrypto.ini)
       - Connects to KMS at 172.17.0.11:3500 via kmsapipc.dll
       - Loads crypto libraries (SLBCryptoAPI.dll, UPSIaccess.dll)
```

### 3.2 Per-Card Execution

```
1. MCES2 → ChipCodingStartProcess.StartCoding()
2. Reader.ConnectToChip() → ATR/ATS/UID
3. DLL_Execute(head, firData, cardData)
       SPI4MLB2.dll:
         - Interpreter.dll runs .per bytecode
         - .per script calls Operas macros (via GenericCrypto.ini)
         - Operas calls KMS → HSM for crypto operations
         - .per script sends APDUs via SCPM callbacks
         - SCPM callbacks → ISPI4MLB2 → MCES2 Reader → Card
4. Reader.DisconnectFromChip()
```

---

## 4. HSM Crypto Operations (GenericCrypto.ini)

### 4.1 API Functions Used

| Function | Purpose |
|---|---|
| `SLBAPIKeyManagerGetKeyByLabel()` | Retrieve key from KMS by label |
| `SLBAPIKeyManagerGetAppKeys()` | Get versioned application keys |
| `SLBAPIKeyManagerGetKeyInformationByRegistrationNumber()` | Get key metadata |
| `SLBCRYPTOAPIExportDESKey()` | Export DES/3DES key encrypted under KEK |
| `SLBCRYPTOAPIBatchDerivation()` | Key diversification (master → card keys) |
| `SLBCRYPTOAPIBatchClearDerivation()` | Key derivation with clear output |
| `SLBCRYPTOAPICalculateKCV()` | Calculate Key Check Value for verification |
| `SLBCRYPTOAPITranslateDESKeyBlock()` | Re-encrypt key under different KEK |
| `SLBCRYPTOAPIAtoBCD()` | ASCII to BCD conversion |
| `KMS_stdSESymEncrypt()` | Symmetric encryption via KMS |

### 4.2 Key Hierarchy

```
Infrastructure Keys (stored in KMS @ 172.17.0.11)
│
├── KEK_INT (varKeyKRN_IntKEK = "4b454b5f494E54")
│       Key Encryption Key — protects exported keys
│
├── CEK_INT (varKeyKRN_IntCEK = "43454b5f494E54")
│       Card Encryption Key — encrypts card-level keys
│
Master Keys (application level, owner: TRANSLINK)
│
├── KAB  (varKeyLABEL_KAB  = "54525F4D504B5F4B4142")
│       Authentication Master Key
│       Diversification data: [REDACTED — see GenericCrypto.ini in source repo]
│
├── KTR  (varKeyLABEL_KTR  = "54525F4D504B5F4B5452")
│       Transport Master Key
│       Diversification data: [REDACTED — see GenericCrypto.ini in source repo]
│
├── KTR0 (varKeyLABEL_KTR0 = "54525F4B454B5F4B545230")
│       Transport KEK (15 sub-versions: KTR0_1 through KTR0_15)
│
├── KAUTHPE (varKeyLABEL_KAUTHPE = "54525F5A4D4B5F4B415554485045")
│       Authentication Key for PE (ZMK-based)
│
└── KAUTHCA (varKeyLABEL_KAUTHCA = "54525F5A4D4B5F4B415554484341")
        Authentication Key for CA (ZMK-based)

Ticketing Keys (versioned, per card application)
│
├── CI   — Card Issuer key (diversified, div data: [REDACTED — see GenericCrypto.ini in source repo])
├── TP   — Transport key
├── TV   — Validation key
├── TS   — Service key
├── TR   — Reload key
├── TD   — Debit key
├── TD1  — Debit key variant
├── CK   — Check key
├── MACX — MAC key X
├── MACY — MAC key Y
├── MKAL — Master Key AL
├── MKBL — Master Key BL
├── ACL  — Access Control key
├── HAUT — Authorization key
├── TLSK — TLS key
├── CERTIF — Certificate key
└── MKDIV  — Master Key Diversification
```

### 4.3 Example Crypto Flow: GetTKt_KTRn Macro

This macro prepares ticketing transport keys for card personalization:

```
Step 1: Get latest TD key version from KMS
        → SLBAPIKeyManagerGetAppKeys(TD, version, ...)
        → SLBAPIKeyManagerGetKeyInformationByRegistrationNumber()

Step 2: Retrieve infrastructure keys
        → SLBAPIKeyManagerGetKeyByLabel(KEK_INT) → varParamOut1
        → SLBAPIKeyManagerGetKeyByLabel(CEK_INT) → varParamOut7

Step 3: Get and diversify KTR master key
        → SLBAPIKeyManagerGetAppKeys(KTR, version, ...)
        → SLBCRYPTOAPIBatchDerivation(KTR, divData_KTR, ...)

Step 4: Export TD key under KEK
        → SLBCRYPTOAPIExportDESKey(TD_key, KEK_INT) → encrypted key
        → SLBCRYPTOAPICalculateKCV() → KCV for verification

Step 5: Derive CI key (batch derivation + translate)
        → SLBCRYPTOAPIBatchClearDerivation(CI, divData_CI, CEK_INT, ...)
        → SLBCRYPTOAPITranslateDESKeyBlock(CI_key, KEK_INT, ...)

Step 6: Repeat for TP, TV, TS, TR keys
        → SLBCRYPTOAPIExportDESKey() for each
        → SLBCRYPTOAPICalculateKCV() for each
```

---

## 5. SCPM Callback Interface (C# ↔ Native DLL)

The C# code registers 22 callbacks that `SPI4MLB2.dll` calls during `.per` script execution:

| # | Callback | Status | Purpose |
|---|---|---|---|
| 1 | ReportError | Implemented | Error reporting from perso engine |
| 2 | SetCardType | Implemented | Set ISO/Type A/Type B/MIFARE |
| 3 | ResetCard | Implemented | Contact card ATR read |
| 4 | SendCommand | Implemented | **Send APDU to card** (core function) |
| 5 | SendPPS | Implemented | Protocol Parameter Selection (T=0/T=1) |
| 6 | SetFrequency | Skipped | Not needed |
| 7 | PowerOff | Skipped | Not needed |
| 8 | SetProtocolParameter | Skipped | Not needed |
| 9 | CLSendPPS | Skipped | Contactless PPS |
| 10 | CLResetCard | Implemented | Contactless ATS/ATQ/UID read |
| 11 | CLPowerOn | Partial | RF field on (skipped due to MCES2 limitation) |
| 12 | CLPowerOff | Partial | RF field off (skipped due to MCES2 limitation) |
| 13 | MifareSetKeys | Not implemented | MIFARE key loading |
| 14 | MifareAuthenticate | Not implemented | MIFARE authentication |
| 15 | MifareGetLastErrorNumber | Not implemented | MIFARE error code |
| 16 | GetHardwareInfo | Implemented | Reader hardware identification |
| 17 | GetHeadCount | Implemented | Number of encoder heads (up to 40) |
| 18 | GetEnvInfo | Implemented | Machine type, module, station, app name |
| 19 | GetVersion | Implemented | Reader firmware version |
| 20 | SetAppValue | Skipped | Application value storage |
| 21 | GetAppValue | Skipped | Application value retrieval |
| 22 | SetAuditField | Skipped | Audit trail field tracking |

---

## 6. Configuration Files

### 6.1 SPI4MLB2.ini (Perso Engine Config)

```ini
[OPERAS]
Address=127.0.0.1:12345          # Operas HSM server address
Program=C:\SPI4MLB2\Operas\XOtm.exe  # Auto-launch path

[GENERAL]
InterpreterDLL=Interpreter.dll   # Script VM
ApplicationsPath=Applications    # .per scripts location
TraceApdu=1                      # Log APDU commands
AllowWrongChecksums=1            # Relaxed checksum validation
```

### 6.2 Operas.ini (HSM Framework Config)

```ini
[SERVER]
Port_1=12345                     # Operas TCP port
Type_1=OPE                       # Operas protocol

[KMS]
Library=OP_GenericCrypto.dll     # Crypto operations handler
Function=GENERICCRYPTO_          # Entry point prefix
Re-entry=10                      # Max concurrent calls
```

### 6.3 GenericCrypto.ini (KMS/HSM Config)

```ini
[KMS]
KMS_Library=kmsapipc.dll         # KMS client library
KMS_IP=172.17.0.11               # KMS server IP
KMS_Port=3500                    # KMS server port
KMS_Enable=1                     # KMS enabled

[DEVICE1] through [DEVICE10]
Device_Type=7                    # HSM device type (10 devices configured)
```

---

## 7. Card Support

| Interface | Type | Implementation |
|---|---|---|
| Contact | ISO 7816 T=0 | Full (ATR, PPS, APDU) |
| Contact | ISO 7816 T=1 | Full (ATR, PPS, APDU) |
| Contactless | Type A (ISO 14443-A) | Full (ATS, APDU) |
| Contactless | Type B (ISO 14443-B) | Full (ATQ, APDU) |
| Contactless | MIFARE | Partial (UID only, auth not implemented) |

---

## 8. Key Observations

### 8.1 HSM Type

This system uses **Thales Operas** — a perso-bureau-specific HSM framework. It is:
- **NOT payShield** (no host commands like KQ/KR/EW/EX)
- **NOT Luna** (no PKCS#11/ProtecToolkit)
- A purpose-built framework for card personalization lines

### 8.2 Application Domain

This is a **ticketing/transport card personalization** system (Calypso-style key hierarchy: CI, TP, TV, TS, TR, TD), not EMV payment card personalization. Key owner is "TRANSLINK".

### 8.3 Crypto Abstraction

The C# code (ISPI4MLB2) **never directly performs cryptographic operations**. All HSM interaction is abstracted through:
1. `.per` scripts → call Operas macros
2. Operas macros → defined in `GenericCrypto.ini`
3. `GenericCrypto.ini` → calls `SLBCryptoAPI` / `kmsapipc` functions
4. These libraries → communicate with HSM hardware

### 8.4 Key Security Model

- Master keys are stored in KMS (172.17.0.11:3500), never in clear text
- Card-level keys are derived inside the HSM via `SLBCRYPTOAPIBatchDerivation`
- Exported keys are always encrypted under KEK_INT
- KCV (Key Check Values) are calculated for every exported key for verification
- Key versioning is supported (up to 16 versions tracked)

### 8.5 Production Environment

```
Perso Machine:  SCP501 (Muhlbauer MCES2, v2.28.32.0)
Station:        PERSO
Module:         MB1301
Application:    SPI4MLB2
Max Heads:      40 (64 in native DLL)
Install Path:   C:\SPI4MLB2\
MCES2 Path:     D:\MCES2\Applications\
License:        Valid through 04/2023
```

---

## 9. File Map

```
trp1002.cperso.thales/
├── ISPI4MLB2/
│   ├── ISPI4MLB2.sln                          # Visual Studio solution
│   ├── ISPI4MLB2/
│   │   ├── ChipCoding.cs                      # Base class: 22 SCPM callbacks + P/Invoke
│   │   ├── ChipCodingStartProcess.cs           # Per-card execution (DLL_Execute)
│   │   └── ChipCodingPrepareProcess.cs         # Job initialization (DLL_Initialize)
│   └── Dlls/
│       ├── SPI4MLB2.ini                        # Perso engine configuration
│       ├── SPI4MLB2_decompiled.c               # Reverse-engineered SPI4MLB2.dll
│       ├── Interpreter_decompiled.c            # Reverse-engineered Interpreter.dll
│       └── REVERSE_ENGINEERING.md              # Architecture analysis
│
├── Operas/
│   ├── Operas.ini                              # Operas framework configuration
│   ├── GenericCrypto.ini                       # HSM crypto macro definitions
│   ├── XOtm.exe                                # Operas HSM server (primary)
│   ├── VOtm.exe                                # Operas variant
│   ├── WOtm.exe                                # Operas variant
│   ├── OperasViewer.exe                        # Admin/debug viewer
│   ├── OP_GenericCrypto.dll                    # Crypto operations plugin
│   ├── OP_Perso.dll                            # Perso operations plugin
│   ├── OP_Transform.dll                        # Data transformation plugin
│   ├── OP_Sleep.dll                            # Echo/health check plugin
│   ├── OP_Tracer.dll                           # Trace logging plugin
│   ├── OP_MakeAudit.dll                        # Audit plugin
│   ├── OP_VISB/OP_VISB.dll                     # TLV processing plugin
│   ├── SLBCryptoAPI.dll                        # Thales crypto API
│   ├── UPSIaccess.dll                          # UPSI access library
│   ├── kmsapipc.dll                            # KMS client library
│   └── THALES MDA/
│       ├── Spi4MLB2.trace.txt                  # Execution trace
│       └── ISpi4Mlb2.trace.txt                 # C# layer trace
│
└── HSM_INTEGRATION_ANALYSIS.md                 # This document
```
