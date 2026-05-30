# SPI4MLB2 + Interpreter.dll — Reverse Engineering Documentation

> Generated 2026-03-16 via Ghidra 12.0.4 headless decompilation.
> To be continued when `.per` script files and vendor documentation become available.

## Table of Contents

1. [Overview](#1-overview)
2. [Binary Details](#2-binary-details)
3. [Full Call Stack](#3-full-call-stack)
4. [SPI4MLB2.dll Deep Analysis](#4-spi4mlbdll-deep-analysis)
5. [Interpreter.dll Deep Analysis](#5-interpreterdll-deep-analysis)
6. [SCPM Callback Architecture](#6-scpm-callback-architecture)
7. [Data Flow](#7-data-flow)
8. [Operas HSM Protocol](#8-operas-hsm-protocol)
9. [Script Encryption](#9-script-encryption)
10. [Checksum Algorithm](#10-checksum-algorithm)
11. [TLV/EMV Processing](#11-tlvemv-processing)
12. [Configuration Reference](#12-configuration-reference)
13. [Decompiled Artifacts](#13-decompiled-artifacts)
14. [Open Questions / Next Steps](#14-open-questions--next-steps)

---

## 1. Overview

The Gemalto/Thales card personalization stack consists of three layers:

```
MCES2 Host (Mühlbauer)
  └── ISPI4MLB2.dll (.NET, our source code)
        └── SPI4MLB2.dll (native C++, Gemalto perso engine)
              └── Interpreter.dll (native C++, script execution engine)
                    ├── .per script files (bytecode personalization scripts)
                    └── Operas/XOtm.exe (HSM key management, TCP)
```

| Component | Type | Size | Functions | Source |
|---|---|---|---|---|
| ISPI4MLB2.dll | .NET (v4.0) | 56 KB | 680 | **We have source** |
| SPI4MLB2.dll | Native x86 (MFC/MSVC6) | 172 KB | 680 | Decompiled |
| Interpreter.dll | Native x86 | 2.0 MB | 7,834 | Decompiled |

---

## 2. Binary Details

### SPI4MLB2.dll

| Property | Value |
|---|---|
| File type | PE32 native Win32 DLL (x86) |
| Built | 2020-02-14 |
| Linker | MSVC 6.0, MFC42 |
| Subsystem | Windows GUI |
| ImageBase | 0x10000000 |
| Exports | 26 functions |
| Imports | KERNEL32, USER32, MFC42, MSVCRT, WSOCK32, VERSION, NETAPI32 |

### Interpreter.dll

| Property | Value |
|---|---|
| File type | PE32 native Win32 DLL (x86) |
| Version | 7.22.3.9 (Thread-Safe) |
| ImageBase | 0x31040000 |
| Exports | 358 functions (56 CR_*, 144 SPI_*, 158 IT_*) |
| Imports | KERNEL32, USER32, GDI32, SHELL32, ADVAPI32, WSOCK32, WS2_32, OLEAUT32, VERSION, NETAPI32, SHLWAPI, comdlg32, WINSPOOL, COMCTL32, OLEACC |

---

## 3. Full Call Stack

### Job Initialization

```
MCES2 Host
  → ChipCodingPrepareProcess.StartCoding(PMProcess)     [C#, our code]
    → ChipCoding.InitINIAndTrace(m_cfgINI)               [C#]
    → ChipCoding.InitializeSPI4MLB2()                     [C#, register 22 callbacks]
    → DLL_RegisterCB(CBFunctions)                         [SPI4MLB2.dll export]
       └── Stores 22 function pointers at 0x100258B8–0x10026430
    → DLL_Initialize(firData, dataLength)                 [SPI4MLB2.dll export]
       ├── GetEnvInfo callback → ISPI4MLB2 → MCES2 (get machine/station/app)
       ├── GetHeadCount callback → ISPI4MLB2 → MCES2 (get head count)
       ├── FUN_1000eb80: copy FIR data into buffer
       └── FUN_10001650 "TheApp.Initialize"
            ├── License gate: TheApp+0x22C must be non-zero
            ├── Read INI [GENERAL] SynchronizeHeads
            ├── If sync enabled → setup head sync events (Win32 Events)
            └── Set TheApp+0x8D4 = 1 (job initialized flag)
```

### Card Personalization

```
MCES2 Host
  → ChipCodingStartProcess.StartCoding(PMProcess)        [C#, our code]
    → ConnectToChip() → read ATR/ATS/UID
    → DataExchange (ATR back to MCES2)
    → DLL_Execute(head, firData, firLen, smcData, smcLen, &reusable)  [SPI4MLB2.dll]
       ├── GetEnvInfo callback (again)
       ├── Validate smcData length > 29 bytes
       ├── Detect & strip SCPM header (0xFF 0xFF 0xFF at offset 0 or 7)
       │   └── Header length = byte[offset+9] + 0x0E + offset + (byte[offset+8] * 0x100)
       ├── Extract first 29 bytes = station/profile identification (26 usable, space-padded)
       ├── FUN_100133a0: XOR checksum verification (see §10)
       ├── FUN_10013480: recompute checksum for audit
       ├── FUN_100017e0 "PersoCard":
       │   ├── Validate head number (1–63, from data)
       │   ├── FUN_10001e70: find/allocate head handler (64-slot array)
       │   ├── Lazy init if TheApp+0x8D4 == 0
       │   ├── FUN_10008800: check if head needs initialization
       │   │   └── FUN_10002670 (set head config)
       │   │   └── FUN_10008590 (set head data)
       │   │   └── FUN_10002b00 (execute head init)
       │   │       └── Interpreter: SPI_ConfigureReader → SPI_OpenScript → SPI_CompileScript
       │   ├── FUN_100021a0: register head activity
       │   └── FUN_10002b70: execute card personalization
       │       └── Interpreter: SPI_ExecScript
       │           └── Bytecode loop: opcode dispatch → CR_*/SCPM_* → callbacks → reader
       ├── SetAuditField callbacks (AUDIT_CHIP, _STA, _CSN, _ATR, _PAN, _CMS, _PER, _PRN_05..99)
       └── Error → FUN_1000fb30 formats NAME/ACTION/ERROR/INFO message
    → DisconnectFromChip()
```

### Job Termination

```
MCES2 Host
  → ChipCodingUnprepareProcess.StartCoding(PMProcess)    [C#, our code]
    → Track per-head completion (placeProcessRunning flags)
    → When all heads done → DllState = COMPLETED
    → DLL_RegisterCB (re-register before terminate)
    → DLL_Terminate()                                     [SPI4MLB2.dll]
       └── FUN_10001f30: logs "TerminateJob done", returns 0
    → DllState = TERMINATED → NEW
    → StopTrace()
```

---

## 4. SPI4MLB2.dll Deep Analysis

### 4.1 Exported Functions (26)

#### Core API (called by ISPI4MLB2.dll via P/Invoke)

| # | Export | RVA | Purpose |
|---|---|---|---|
| 1 | `DLL_Execute` | 0xc940 | Execute card personalization for a specific head |
| 2 | `DLL_GetAuditFields` | 0xc170 | Retrieve audit trail data |
| 3 | `DLL_Initialize` | 0xc3f0 | Initialize perso job with FIR/Coding_Standard data |
| 4 | `DLL_RegisterCB` | 0xc080 | Register 22 callback function pointers |
| 5 | `DLL_Terminate` | 0xda60 | Terminate perso job |

#### SCPM Contact Interface

| # | Export | RVA | Internal handler |
|---|---|---|---|
| 23 | `SCPM_OnCmm` | 0xdb50 | FUN_10002d60 — Power on, set frequency |
| 26 | `SCPM_SendPPSCmm` | 0xdbb0 | FUN_10003930 — PPS negotiation |
| 13 | `SCPM_InCmm` | 0xdc20 | FUN_10003b70 — Read data from reader |
| 24 | `SCPM_OutCmm` | 0xdc80 | FUN_10003e30 — Write data to reader |
| 25 | `SCPM_SendAPDU` | 0xdcf0 | FUN_10004100(…, contactless=0) — Send APDU |
| 22 | `SCPM_OffCmm` | 0xdd60 | FUN_100044d0 — Power off |
| 12 | `SCPM_ChangeProtocolParameters` | 0xdda0 | FUN_10006440 |

#### SCPM Contactless Interface

| # | Export | RVA | Internal handler |
|---|---|---|---|
| 9 | `SCPM_CLESS_SelectFieldStrength` | 0xddf0 | FUN_10004d30 |
| 6 | `SCPM_CLESS_Activate` | 0xde50 | FUN_100045c0 |
| 10 | `SCPM_CLESS_SelectType` | 0xdea0 | FUN_10004ed0 |
| 8 | `SCPM_CLESS_SelectDataRate` | 0xdef0 | FUN_10006530 |
| 7 | `SCPM_CLESS_ChangeProtocolParameters` | 0xdf50 | FUN_10006510 |
| 11 | `SCPM_CLESS_SendAPDU` | 0xdfa0 | FUN_10004100(…, contactless=1) — Same as contact but flag=1 |

#### SCPM MIFARE Interface

| # | Export | RVA | Internal handler |
|---|---|---|---|
| 15 | `SCPM_MIFARE_Authentication` | 0xe010 | FUN_100056c0 |
| 17 | `SCPM_MIFARE_LoadKey` | 0xe080 | FUN_100055c0 |
| 18 | `SCPM_MIFARE_Read` | 0xe0f0 | FUN_100059e0 |
| 21 | `SCPM_MIFARE_Write` | 0xe150 | FUN_10005ca0 |
| 19 | `SCPM_MIFARE_Request` | 0xe1b0 | FUN_100050d0 |
| 14 | `SCPM_MIFARE_Anticoll` | 0xe210 | FUN_10005250 |
| 20 | `SCPM_MIFARE_Select` | 0xe270 | FUN_10005430 |
| 16 | `SCPM_MIFARE_GetLastErrorNumber` | 0xe2d0 | FUN_10006650 |

### 4.2 Key Internal Functions

| Address | Deduced Name | Purpose |
|---|---|---|
| FUN_10001650 | TheApp.InitJob | License check, head sync setup, set initialized flag |
| FUN_100017e0 | TheApp.PersoCard | Main card perso orchestrator (validate head, init, execute) |
| FUN_10001e70 | FindOrAllocHeadHandler | Lookup/allocate in 64-slot head handler array |
| FUN_10001f30 | TheApp.TerminateJob | Logs "TerminateJob done", returns 0 |
| FUN_100020c0 | SetupHeadSynchronization | Create Win32 Events for Start/End-of-Perso barriers |
| FUN_10002670 | SetHeadConfig | Configure per-head reader settings |
| FUN_10002b00 | ExecuteHeadInit | Per-head initialization (first card on head) |
| FUN_10002b70 | ExecuteCardPerso | Actual card personalization execution |
| FUN_1000ae60 | LoadInterpreterDLL | LoadLibrary + GetProcAddress for 10 SPI_* functions |
| FUN_1000bd30 | TheApp.FullInit | Cascading subsystem init (config, license, reader, interpreter, audit) |
| FUN_1000be70 | TheApp.ReleaseResources | DLL_PROCESS_DETACH cleanup |
| FUN_1000bf50 | DllMain handler | Calls FullInit on PROCESS_ATTACH |
| FUN_1000e740 | CString constructor | MFC CString initialization |
| FUN_1000eb80 | BufferAssign | Copy data into dynamic buffer object |
| FUN_1000f140 | AcquireLock | EnterCriticalSection wrapper |
| FUN_1000f150 | ReleaseLock | LeaveCriticalSection wrapper |
| FUN_1000fb30 | FormatErrorDescription | Build NAME/ACTION/ERROR/INFO string |
| FUN_100104f0 | TraceLog | General-purpose trace with level filtering |
| FUN_10010ff0 | StringBufferInit | Initialize internal string buffer object |
| FUN_10011110 | StringGetLength | Get string/buffer length |
| FUN_10011350 | StringAssignFromData | Assign string from char* + length |
| FUN_10011440 | StringAppend | Append to string buffer |
| FUN_10011620 | StringGetDataLength | Get data portion length |
| FUN_10011850 | StringGetPtr | Get char* pointer from string object |
| FUN_100133a0 | VerifyChecksum | XOR checksum verification (returns 0/1) |
| FUN_10013480 | ComputeChecksum | XOR checksum computation (outputs hex string) |
| FUN_10014ea0 | INIHandler constructor | INI file reader with critical section |
| FUN_10014f40 | INIHandler destructor | Cleanup entries, DeleteCriticalSection |

### 4.3 Global Data Addresses

| Address | Purpose |
|---|---|
| DAT_10025918 | TheApp global singleton object |
| DAT_100258B8–DAT_10026430 | Callback function pointer table (22 entries) |
| DAT_100263DC | CB_ReportError pointer (callback #1) |
| DAT_10026420 | CB_GetEnvInfo pointer |
| DAT_10026430 | CB_SetAuditField pointer |
| DAT_100261E4 | AllowWrongChecksums flag |
| DAT_100269B0 | Global tracer object |
| DAT_100269B8 | Reference checksum value (8 bytes) |
| DAT_1001994C | Checksum substitution table (256 bytes) |

### 4.4 TheApp Object Layout (at DAT_10025918)

| Offset | Field |
|---|---|
| +0x000 | vtable pointer |
| +0x22C | License verified flag (0 = invalid) |
| +0x23C | Head handler array base (64 slots) |
| +0x8CC | (reserved) |
| +0x8D0 | AllowWrongChecksums mode |
| +0x8D4 | Job initialized flag (0/1) |

### 4.5 Error Description Object Layout (param in FUN_1000fb30)

| Offset | Field |
|---|---|
| +0x08 | Error code (long) |
| +0x10 | NAME string |
| +0x40 | ACTION string |
| +0x70 | INFO string |
| +0xA0 | ERROR description string |
| +0xD0 | Composed output string |

---

## 5. Interpreter.dll Deep Analysis

### 5.1 Dual API Pattern

Every function exists as:
- `IT_*` — uses global default context (single-threaded, context handle = 0)
- `SPI_*` — takes explicit context handle (multi-threaded, thread-safe)

`SPI_*` resolves handle via `FUN_3104d0dc(handle, &ctx_ptr)`.

### 5.2 Script Execution Engine

#### Execution Model

The `.per` script is compiled to bytecode. Execution uses a **256-entry opcode dispatch table**.

```
Context object (very large, offsets up to 0x7B460+):
  +0x0020  W buffer pointer (64KB, data to card)
  +0x00A6  Script line pointer array base
  +0x00A8  Current instruction pointer
  +0x00AB  Current line index in pointer array
  +0x00AC  (alias for above in some contexts)
  +0x00C0  Current opcode byte
  +0x00F4  Per-script W persist buffer array (16 entries × 0x3CB0 bytes)
  +0x0148  First image record size
  +0x0164  Script count (max 16)
  +0x02AC  Current absolute line number (program counter)
  +0x02B0  Current script index
  +0x02E0  Operas socket handle (-1 = disconnected)
  +0x2109  Retest flag
  +0x210C  First-chance exception flag
  +0x2164  Opcode dispatch table pointer (256 entries × 4 bytes)
  +0x1C6B8 Current script object
  +0x1C6BA Encryption flag (bit 31) + version
  +0x1C6C0 Number of image records
  +0x1ED13 Work-in-progress flag
  +0x1ED1A Context initialized flag
  +0x1ED1D (used in GetResolvedScript)
  +0x6BD54 SCPM enabled flag
  +0x6BD58 SCPM alias handle
  +0x7B460 Script text storage
  +0x89F8  Operas service table
  +0x1B058 Per-reader callback pointer array (21 slots)
```

#### Core Execution Functions

| Function | Address | Purpose |
|---|---|---|
| IT_ExecScript | 0x310443BB | Wrapper → ExecScriptPart(0) |
| SPI_ExecScript | 0x310443C7 | Multi-context variant |
| IT_ExecScriptPart | 0x310443D9 | Execute from specific part index |
| FUN_3104443D | 0x3104443D | **Real entry**: acquires lock, checks WIP flag, calls compiler if needed, calls execution loop |
| FUN_3106D182 | 0x3106D182 | **Main execution loop**: iterates scripts, saves/restores W buffers, loops FUN_3106D629 |
| FUN_3106D629 | 0x3106D629 | **Single-line dispatcher**: reads opcode, dispatches via table[opcode], handles special returns |
| IT_ExecPreTest | 0x3104461C | Pre-test phase (ATR verification, etc.) |
| IT_ExecThis | 0x31044793 | Execute script snippet by name |
| IT_ExecLine | 0x31044B89 | Single-line execution (debugger support) |
| IT_ExecLineStepInto | 0x31044B03 | Step-into debugging |
| IT_ExecLineStepOut | 0x31044B71 | Step-out debugging |
| IT_ContinueScript | 0x31044910 | Resume execution from current position |

#### Special Return Codes from Opcode Handlers

| Code | Meaning |
|---|---|
| 0x00 | Success, continue |
| 0x78 | Error condition |
| 0x96 | End of script/part (normal termination) |
| 0x97 | NOP (treated as success) |
| 0x99 | Error condition |
| 0xDB | Triggers additional processing |

### 5.3 Script Loading & Compilation

| Function | Address | Purpose |
|---|---|---|
| IT_OpenScript | 0x31057400 | Load .per file (with decryption) |
| FUN_31057472 | 0x31057472 | Internal: resolve path → open file → decrypt → load text |
| IT_SetScript | 0x310576CC | Load script from in-memory string |
| IT_GetScript | 0x31057DDE | Retrieve current script text |
| IT_GetResolvedScript | 0x31057FBB | Get compiled/resolved form |
| IT_CompileScript | 0x31058331 | Trigger compilation |
| FUN_3105838B | 0x3105838B | **The compiler**: ATR matching with '?' wildcards, bytecode generation, script chaining |
| FUN_31059A2C | 0x31059A2C | Script text loading into context |
| FUN_31059C3D | 0x31059C3D | Auto-compile if needed |

#### Compilation Flow

1. `GetTickCount()` — timestamp
2. Initialize compilation state
3. **ATR matching**: iterate ATR patterns, support `?` wildcard per nibble
4. If no match → error 0xAE
5. On match → `FUN_3105B330` (bytecode generation)
6. Handle script chaining via `FUN_31061A54`

### 5.4 Card Reader Abstraction

**21 reader slots** (indices 0–20, slot 20 = contactless). Polymorphic via vtable.

| Function | Purpose |
|---|---|
| SPI_ConfigureReader | Configure reader type, COM port, speed, TCP address |
| SPI_ConnectReader | Connect to configured reader |
| SPI_DisconnectReader | Disconnect reader |
| CR_ResetCard | ATR reset via vtable+0xBC |
| CR_PowerOff | Power off via vtable+0xC4 |
| CR_SendPTS | Protocol Type Selection (T=0/T=1) |
| CR_SendIsoIn | ISO Case 2 (data to card) |
| CR_SendIsoOut | ISO Case 3 (data from card) |
| CR_SendIsoT1 | T=1 protocol command |
| CR_SendIsoInAsync | Async variant |
| CR_SendIsoOutAsync | Async variant |
| CR_SendIsoT1Async | Async variant |
| CR_GetCardPosition | Card presence detection |
| CR_IsCardPresent | Card presence check |
| CR_IsCardAbsent | Card absence check |
| CR_GetProtocol | Current protocol (T=0/T=1) |
| CR_GetVersion | Reader firmware version |
| CR_GetReaderList | Enumerate available readers |
| CR_GetReaderDescription | Reader description string |

Supported reader types: **PC/SC**, **TCP/IP** (serial-over-TCP), **direct serial**.

### 5.5 Buffer Management

| Buffer | Context offset | Size | Purpose |
|---|---|---|---|
| **W buffer** | +0x20 | 64 KB | Data TO card (command payload) |
| **R buffer** | (nearby) | 64 KB | Data FROM card (response) |
| **W persist** | +0xF4 | 16 × 0x3CB0 | Per-script W buffer save/restore |
| **VR buffers** | (via SPI_SetBufferVR) | variable | Virtual reader buffers |

Functions: `SPI_GetBufferW`, `SPI_SetBufferW`, `SPI_GetBufferR`, `SPI_SetBufferR` (binary), plus `*Text` variants (hex-encoded).

### 5.6 Image (Card Data Record) Management

"Images" = **card personalization data records**, NOT graphical images.

| Function | Purpose |
|---|---|
| SPI_SetImageFile | Load multi-record card data (CR/LF delimited) |
| SPI_OpenImageFile | Open image file from disk |
| SPI_GetCurrentImage | Get current card record (binary) |
| SPI_GetCurrentImageText | Get current card record (hex) |
| SPI_GetCurrentImageProtected | Get protected fields |
| SPI_SetCurrentImageRecordId | Select which card record to use |
| SPI_GetNbOfImages | Count of card records |
| SPI_IsImageNeeded | Check if script requires image data |
| SPI_GetFieldFromCurrentImage | Extract specific field from record |

### 5.7 Context Management

| Function | Purpose |
|---|---|
| SPI_AllocContext | Allocate new interpreter context (handle=1 = default) |
| SPI_FreeContext | Free context |
| SPI_GetVersion | Returns "Interpreter.dll version 7.22.3.9" |
| SPI_SetEnvironment | Set environment variable in context |
| SPI_GetEnvironment | Get environment variable |
| SPI_SetCallbacks | Register host callback functions |
| SPI_SetEXTERNCallbackPointer | Register EXTERN callback |
| SPI_SetMainWindow | Set parent window handle |
| SPI_GetWorkingStatus | Check if script is executing |
| SPI_IsExecutionTerminated | Check if execution finished |
| SPI_GetLastError | Get last error code |
| SPI_GetLastErrorPosition | Get error position (line/col) |
| SPI_GetErrorDescription | Get error description string |
| SPI_GetLastMessage | Get last interpreter message |
| SPI_GetLastCardStatus | Get last card operation status |
| SPI_GetLastReaderStatus | Get last reader operation status |

### 5.8 SCPM Function Redirection

| Function | Purpose |
|---|---|
| SPI_SetScpmRemapLibrary | Load external SCPM DLL, resolve exports |
| SPI_SetScpmCtxAlias | Map context to SCPM alias handle |
| SPI_GetScpmRemapLibraryStatus | Get capability bitmask (3 feature flags) |

Required SCPM DLL exports: `SCPM_OnDelay`, `SCPM_ChangeProtocolParameters`, `SCPM_OnCmm`, `SCPM_SendPPSCmm`, `SCPM_InCmm`, `SCPM_OutCmm`, `SCPM_SendAPDU`.

### 5.9 Configuration & Project Management

| Function | Purpose |
|---|---|
| SPI_LoadMainConfigFile | Load main INI configuration |
| SPI_SaveMainConfigFile | Save main INI |
| SPI_LoadProjectConfigFile | Load project-specific config |
| SPI_SaveProjectConfigFile | Save project config |
| SPI_OpenProject | Open a perso project |
| SPI_SaveProject | Save project |
| SPI_GetConfigOption | Read config value |
| SPI_SetConfigOption | Write config value |
| SPI_GetConfigBool | Read boolean config |
| SPI_SetConfigBool | Write boolean config |
| SPI_GetConfigLong | Read long config |
| SPI_SetConfigLong | Write long config |
| SPI_GetConfigStr | Read string config |
| SPI_SetConfigStr | Write string config |
| SPI_SetTraceFile | Set trace output file |
| SPI_SetTraceLevel | Set trace verbosity |
| SPI_ConfigureTrace | Configure trace subsystem |

---

## 6. SCPM Callback Architecture

The SCPM (Smart Card Protocol Manager) layer connects SPI4MLB2's perso scripts to the physical reader hardware through ISPI4MLB2.dll:

```
.per script (in Interpreter.dll)
  → SCPM_SendAPDU (SPI4MLB2.dll export)
    → FUN_10004100 (internal handler)
      → callback function pointer at DAT_100258xx
        → ISPI4MLB2.ChipCoding.SendCommand [C#, our code]
          → Reader.SendAPDU(apdu, out chipResponse) [MCES2 SDK]
            → Physical card reader hardware
```

### Callback Table (22 entries, stored at 0x100258B8)

| # | Callback | Global address | C# implementation |
|---|---|---|---|
| 1 | ReportError | DAT_100263DC | ChipCoding.ReportError |
| 2 | SetCardType | DAT_100263E0 | ChipCoding.SetCardType |
| 3 | ResetCard | DAT_100263E4 | ChipCoding.ResetCard |
| 4 | SendCommand | DAT_100263E8 | ChipCoding.SendCommand |
| 5 | SendPPS | DAT_100263EC | ChipCoding.SendPPS |
| 6 | SetFrequency | DAT_100263F0 | ChipCoding.SetFrequency (skipped) |
| 7 | PowerOff | DAT_100263F4 | ChipCoding.PowerOff (skipped) |
| 8 | SetProtocolParameter | DAT_100263F8 | ChipCoding.SetProtocolParameter (skipped) |
| 9 | CLSendPPS | DAT_100263FC | ChipCoding.CLSendPPS (skipped) |
| 10 | CLResetCard | DAT_10026400 | ChipCoding.CLResetCard |
| 11 | CLPowerOn | DAT_10026404 | ChipCoding.CLPowerOn (no-op) |
| 12 | CLPowerOff | DAT_10026408 | ChipCoding.CLPowerOff (no-op) |
| 13 | MifareSetKeys | DAT_1002640C | ChipCoding.MifareSetKeys (not implemented) |
| 14 | MifareAuthenticate | DAT_10026410 | ChipCoding.MifareAuthenticate (not implemented) |
| 15 | MifareGetLastErrorNumber | DAT_10026414 | ChipCoding.MifareGetLastErrorNumber (not impl.) |
| 16 | GetHardwareInfo | DAT_10026418 | ChipCoding.GetHardwareInfo |
| 17 | GetHeadCount | DAT_1002641C | ChipCoding.GetHeadCount |
| 18 | GetEnvInfo | DAT_10026420 | ChipCoding.GetEnvInfo |
| 19 | GetVersion | DAT_10026424 | ChipCoding.GetVersion |
| 20 | SetAppValue | DAT_10026428 | ChipCoding.SetAppValue (skipped) |
| 21 | GetAppValue | DAT_1002642C | ChipCoding.GetAppValue (skipped) |
| 22 | SetAuditField | DAT_10026430 | ChipCoding.SetAuditField (skipped) |

---

## 7. Data Flow

### Per-Card Personalization Data Flow

```
1. MCES2 Host prepares PMProcess with DataField "Coding_Standard"
   └── Contains: SCPM header + station ID (29 bytes) + card data (hex-encoded)

2. ISPI4MLB2.ChipCodingStartProcess:
   ├── Connects to chip (contact/contactless)
   ├── Reads ATR/ATS/UID
   └── Calls DLL_Execute(head, firData, smcData, ...)

3. SPI4MLB2.DLL_Execute:
   ├── Strips SCPM header (if present: 0xFF 0xFF 0xFF marker)
   ├── Extracts 29-byte station/profile header
   ├── Verifies XOR checksum
   └── Calls PersoCard → Interpreter

4. Interpreter.dll:
   ├── Script reads fields from "image" (card data record)
   ├── Builds APDU in W buffer
   ├── Calls SCPM_SendAPDU or CR_SendIso*
   │   └── Routed through callbacks → ISPI4MLB2 → MCES2 → reader → card
   ├── Response stored in R buffer
   └── Script processes response, builds next APDU

5. On completion:
   ├── Audit fields populated (CHIP, STA, CSN, ATR, PAN, CMS, PER, PRN_05..99)
   └── Return to MCES2 host with PMProcessResult
```

### SMC Data Structure

```
Offset 0x00: [Optional SCPM header]
  Bytes 0-2 or 7-9: 0xFF 0xFF 0xFF (header marker)
  Byte [offset+8]: high byte of app name length
  Byte [offset+9]: low byte of app name length
  Header total = byte[offset+9] + 0x0E + offset + byte[offset+8]*0x100

After header:
  Bytes 0-28: Station/profile identification (26 usable, space-padded)
  Bytes 29+:  Card data (hex-encoded electrical fields)
              Must be multiple of 8 chars for checksum
              Last 8 chars = checksum
```

---

## 8. Operas HSM Protocol

### Connection

- Transport: **TCP/IP socket**
- Default port: **10002** (configurable in INI `[OPERAS] Address`)
- Auto-launch: `.\Operas\XOtm.exe` or path from INI `[OPERAS] Program`

### Session Initialization

```
→ COMMAND SETNAME Interpreter.dll
← COMMAND SETNAME OK
```

### Health Check

```
→ ECHO 12345678
← ECHO 0000 12345678
```

`0000` = success status code. Timeout: 100 polls × 50ms = 5 seconds.

### Connection State

- Socket handle stored at context offset +0x2E0
- Handle = -1 means disconnected
- Service table at context offset +0x89F8
- Service record: host at +0x28, port at +0x48

### Known Commands

Only `ECHO` and `COMMAND SETNAME` identified from decompilation. The actual HSM crypto commands (key derivation, MAC, encipherment) are issued by the `.per` script through opcode handlers — these remain unmapped until we have script files.

---

## 9. Script Encryption

### Mechanism

`.per` scripts can be encrypted with a site-specific key.

### Key Storage

- INI section: `[SELECTIONS]`
- Key name: `SiteKey`
- Functions: `IT_SetAccessKey` (write), `IT_IsAccessKeyLoaded` (check)
- `IT_LoadAccessKey*` family is **obsoleted**

### Decryption Flow (in FUN_31059450)

1. Open `.per` file via `FUN_3110E636`
2. Call `FUN_3110B978()` to detect encryption (returns 0 = plaintext)
3. If encrypted:
   - Retrieve SiteKey via `FUN_31049D1A()`
   - Set decryption key via `FUN_3110B6EB(key, 1, 0)`
   - **Version < 3**: Direct key-based decryption
   - **Version >= 3**: SPTools service decryption:
     - Login via `FUN_311117CA` using `WinSPI` app from `[SPTOOLS]` INI section
     - Decrypt via `FUN_31111D39` (`WinSPI_DecipherData` service)
     - Apply via `FUN_311085E4(1)`
4. On success → load decrypted text via `FUN_31059A2C(0)`
5. On failure → "Can not decipher script, please reload access key"

---

## 10. Checksum Algorithm

### Location

- Verify: `FUN_100133a0` in SPI4MLB2.dll
- Compute: `FUN_10013480` in SPI4MLB2.dll

### Algorithm

```
Input: hex string, must be multiple of 8 characters
Substitution table: 256-byte table at DAT_1001994C

hash[8] = {0, 0, 0, 0, 0, 0, 0, 0}

For each 8-character block:
  For i = 0 to 7:
    hash[i] = substitution_table[hash[i] XOR char[block_offset + i]]

Compare hash[0..7] against reference at DAT_100269B8 (8 bytes)
```

### Bypass

INI setting `[GENERAL] AllowWrongChecksums=1` allows personalization to proceed even if checksum fails (logs warning instead of error).

---

## 11. TLV/EMV Processing

### Proprietary Envelope Format

```
Tag byte: 0xE0–0xE5 (short format, 7-byte tag IDs)
          0xE8–0xED (long format, 10-byte tag IDs)
Sub-tags:
  C0: Card data (required)
  C1: Additional data field 1
  C2: Additional data field 2
  C3: Additional data field 3
Length: BER-TLV encoding (via FUN_31074E56)
Error: 0xAF for structural errors
```

### BER-TLV Support

- Tag registers: `T1BER`, `T2BER`, `T3BER` (via `FUN_310A40A9`)
- Standard EMV tag parsing supported
- EMV mode toggle: "Set operating mode to EMV rules"

### TLV Extraction Modes (in IEX_EvalTLV)

| Mode | Behavior |
|---|---|
| 0x15–0x17 | Direct copy, length = value_len × 2 |
| 0x18–0x1A | Conditional copy (skip if length 0) |
| 0x1B–0x1D | Skip tag+length, copy value only |
| 0x1E–0x20 | Extract length as 2-byte big-endian |

---

## 12. Configuration Reference

### ISPI4MLB2.ini

```ini
[Trace]
Enable=1              # 0/1
MaxSize=<bytes>       # Max trace file size
Flush=1               # 0/1, flush after each write
Level=3               # Trace verbosity (1-5)
File=C:\SPI4MLB2\ISPI4MLB2.Trace.txt

[GENERAL]
NbrHeads=<int>        # Number of encoder heads
MachineType=SCP501    # Machine type identifier
StationName=PERSO     # Station name
ApplicationName=SPI4MLB2
TraceApdu=1           # 0/1, trace APDU commands
```

### SPI4MLB2.ini

```ini
[TRACE]
File=C:\SPI4MLB2\Spi4MLB2.trace.txt
Enable=1
Level=5               # 1-5
Flush=1               # 0/1
Backup=5              # Number of backup trace files
MaxSize=10000000      # Max trace file size (bytes)
InterpreterTraceLevel=5

[GENERAL]
InterpreterDLL=Interpreter.dll
ApplicationsPath=Applications        # Where .per scripts live
License=<256-byte hex blob>          # License key
TraceApdu=1                          # 0/1
AllowWrongChecksums=1                # 0/1, bypass checksum validation
SynchronizeHeads=<int>               # 0/1, enable multi-head sync
# ApduTimeout=30s
# KeepLoaded=1
# PreExecutionDelay=2500ms
# RelaxCouplerTimings=1
# SkipIdentificationReset=1
# AtrMaxAttempts=2

[OPERAS]
Address=127.0.0.1:12345              # HSM address:port
Program=C:\SPI4MLB2\Operas\XOtm.exe # Auto-launch path

[HEAD_SYNCH]                         # Written dynamically when sync enabled
HeadCount=<int>
Machine=<string>
```

### INI File Search Order (SPI4MLB2.dll)

1. `C:\SPI4AI\SPI4MLB2.ini`
2. `C:\ProgramData\Datacard\Adaptive Issuance Suite\AppRepository\Apps\Sc_v1.0\ISPI4AI\SPI4MLB2.ini`

### INI File Search Order (ISPI4MLB2.dll)

1. `C:\ProgramData\Muelbauer\ChipEncoding\ISPI4MLB2.ini`
2. `C:\SPI4MLB2\ISPI4MLB2.ini`

---

## 13. Decompiled Artifacts

| File | Content | Lines |
|---|---|---|
| `Dlls/SPI4MLB2_decompiled.c` | Ghidra pseudo-C for SPI4MLB2.dll (680 functions) | 23,119 |
| `Dlls/Interpreter_decompiled.c` | Ghidra pseudo-C for Interpreter.dll (7,834 functions) | 242,971 |
| `Dlls/REVERSE_ENGINEERING.md` | This document | — |

### Ghidra Project

- Location: `/tmp/ghidra_project/SPI4MLB2_Project`
- Contains analyzed binaries for both DLLs
- Can be reopened in Ghidra GUI for interactive analysis

### Tools Used

- Ghidra 12.0.4 PUBLIC (NSA, headless mode)
- OpenJDK 21.0.10 (Homebrew)
- macOS objdump (for initial PE analysis)

---

## 14. Open Questions / Next Steps

### Priority 1: Need `.per` Script Files

With even one `.per` file we can:
- Map the 256 opcode dispatch table to script language commands
- Understand the script syntax and available instructions
- See how card data fields are addressed and written
- Identify which Operas HSM commands are used

### Priority 2: Need Vendor Documentation

- **Interpreter SDK docs** (Gemalto ships to integrators) — defines the `.per` script language
- **SCPM protocol spec** — formal definition of the SCPM callback contract
- **Operas API reference** — full HSM command vocabulary

### Priority 3: Interactive Ghidra Analysis

To push understanding further without vendor docs:
1. Open Ghidra project in GUI
2. Navigate to `FUN_3106D629` (single-line dispatcher)
3. Follow the opcode dispatch table at context+0x2164
4. Map each of the 256 handler functions by tracing their string references and callback usage
5. Rename functions as patterns emerge

### Priority 4: Remaining DLLs

| DLL | Size | Priority | Reason |
|---|---|---|---|
| BaseLib.dll | 991 KB | Low | MCES2 framework, defines interfaces only |
| ChipCodingBaseLib.dll | 99 KB | Low | IChipCoding interface definition |
| LightCore.dll | 59 KB | Low | IoC/DI container |

### Known Limitations of Current Analysis

1. **Function names**: ~8,500 of ~9,200 functions are unnamed (`FUN_XXXXXXXX`)
2. **Variable names**: All are `local_XX`, `param_X` — no original names
3. **Types**: Many are `undefined4`, `void*` — no original struct/class definitions
4. **Opcode semantics**: 256-entry dispatch table identified but individual opcodes unmapped
5. **Operas crypto commands**: Only ECHO and SETNAME identified; actual HSM operations unknown
6. **License algorithm**: Structure visible but verification logic not fully traced
