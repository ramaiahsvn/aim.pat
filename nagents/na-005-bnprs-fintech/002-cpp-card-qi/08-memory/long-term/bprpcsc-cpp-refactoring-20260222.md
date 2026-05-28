# Work Log — bpr.cpp (2026-03-05)

## Summary
Extended `BprPcSc` from a Sunmi-only Android library to a **multi-device single `.so`** that
supports 7 Android POS device families at runtime, selected via `pcsc.setContext(ctx, deviceType)`.
Also added QI card-read operations to the Sunmi backend, eliminating the BprQiEmv JNI dependency
for the Sunmi integration.

---

## Commits (oldest → newest)

### `45aa480` — Add APDU request/response logging to BprPcSc examples
- C++ standalone example: `logApduReq`/`logApduResp` helpers hex-print every `card.transmit()` call
- C# example: log request/response bytes around transmit
- Android example: JNI callback `pcsc.nativeApduLog` / `ApduLogListener`; logging is wired into
  `Card::transmitRaw()` so all exchanges are captured regardless of which high-level method calls it

---

### `dddea9d` — Add BprPcSc SO_Android_Multi — runtime multi-device backend dispatch
Introduces `PCSC_PLATFORM_ANDROID_MULTI`: a single `libBprPcSc.so` that selects its card reader
backend at runtime based on `deviceType` passed to `setContext()`.

**New source files:**
| File | Purpose |
|------|---------|
| `android_iface.h` (→ later renamed `android_backends.h`) | `IContextBackend` / `ICardBackend` abstract interfaces; `DeviceType` enum; factory declarations |
| `backend_android_dispatch.cpp` | Owns pimpl state; delegates all `pcsc::Context`/`Card` calls to the active backend; `JNI_OnLoad`; APDU logging in `transmitRaw()` |
| `backend_android_stubs.cpp` | Placeholder factory stubs for PAX/Feitian/NexGo/Wizar (delegate to PCSCLite until vendor AIDL implemented) |

**Modified files:**
- `backend_android.cpp` — added `PcscLiteContextBackend` / `PcscLiteCardBackend` for MULTI builds
- `backend_android_sunmi.cpp` — added `SunmiContextBackend` / `SunmiCardBackend` + `sunmi_multi_jni_init()`
- `BprPcSc_jni_exports.cpp` — unified ANDROID/SUNMI/MULTI; `setContext` now takes `(ctx, deviceType)` in MULTI
- `bpr_pcsc_src.cmake` — `BPR_PCSC_BACKEND_ANDROID_MULTI` variable
- `CMakeLists.txt` — `SO_Android_Multi` build target
- `Makefile` — android-multi platforms and `make` target
- `pcsc.java` — `DEVICE_*` constants; `setContext(ctx, deviceType)` signature
- `MainActivity.java` — passes `pcsc.DEVICE_SUNMI` to `setContext`

---

### `408ec4c` — Rename android_iface.h → android_backends.h
Header rename across all files that included it.

---

### `f2806e5` — Add PAX POS backend to BprPcSc multi-device build
- `backend_android_pax.cpp` — C++ backend using PAX CloudPOS SDK (`com.unionpay.cloudpos`) via JNI
- `PaxPcScHelper.java` — Java helper: `POSTerminal` → `SmartCardReaderDevice` → `CPUCard`
- Removed PAX stub from `backend_android_stubs.cpp`

---

### `91995ea` — Update BprPcScSample: update DEVICE_PAX comment in pcsc.java
Minor comment update to reflect real PAX CloudPOS SDK usage.

---

### `ee6d72d` — Add DEVICE_TYPE constant to BprPcScSample MainActivity
Replaced hardcoded `DEVICE_SUNMI` with a `DEVICE_TYPE` constant at the top of the class, making
it easy to switch between devices without touching session logic.

---

### `068d55e` — Add Feitian backend to BprPcSc multi-device build
- `backend_android_feitian.cpp` — C++ backend using Feitian SDK (`com.ftpos.library.smartpos`) via JNI;
  bridges async `openCard` callback to blocking C++ semantics with `CountDownLatch`
- `FeitianPcScHelper.java` — Java helper: `ServiceManager.bindPosServer()` → `IcReader` → `openCard` / `sendApduCustomer`
- Removed Feitian stub from `backend_android_stubs.cpp`

---

### `185b687` — Switch BprPcSc PAX backend to NeptuneLite SDK (PAX A9/A910S)
Replaced PAX CloudPOS SDK with **PAX NeptuneLite DAL SDK** in `PaxPcScHelper.java`.
- CloudPOS required a missing device-side jar (`/data/cloudpossdk/cloudpossdkimpl.jar`)
- NeptuneLite is built into PAX firmware and works out of the box
- Permission changed from `CLOUDPOS_SMARTCARD` to `com.pax.permission.ICC`

---

### `11b7d23` — Add Wizar backend to BprPcSc multi-device build
- `backend_android_wizar.cpp` — C++ backend using Wizar CloudPOS SDK (`com.cloudpos.*`) via JNI;
  `POSTerminal` → `SmartCardReaderDevice` → `CPUCard` pattern, mirroring the PAX backend
- `WizarPcScHelper.java` — Java helper: `open()`, `waitForCardPresent()`, `transmit()`, `disconnectCard()`
- Removed Wizar stub from `backend_android_stubs.cpp`

---

### `8bcc17d` — Add NexGo backend to BprPcSc multi-device build
- `backend_android_nexgo.cpp` — C++ backend using NexGo SmartPOS SDK v3 (`com.nexgo.oaf.apiv3.*`) via JNI;
  `APIProxy` → `DeviceEngine` → `CardReader.searchCard` (CountDownLatch) → `CPUCardHandler.powerOn` → `Ddi.ddi_iccpsam_exchange_apdu`
- `NexGoPcScHelper.java` — Java helper with async `searchCard` + `CountDownLatch`, DDI transmit
- Removed NexGo stub (last vendor stub removed); `backend_android_stubs.cpp` now empty
- `AndroidManifest.xml`: added `com.nexgo.permission.DEVICE`

---

### `5d2631c` — Add Ciontek backend to BprPcSc multi-device build
- `backend_android_ciontek.cpp` — C++ backend using Ciontek POS AIDL service (`posmanager` → `ICiontekPosService`);
  `IccCheck` → `IccOpen` → `IccCommand` → `IccClose` pattern
- `CiontekPcScHelper.java` — Java helper: `ServiceManager` reflection-based open,
  polling `waitForCardPresent()`, 520-byte Ciontek APDU buffer format

---

### `be06551` — Add Futronic F8 backend to BprPcSc multi-device build
- `backend_android_futronic.cpp` — C++ backend using ACS USB Smart Card Reader SDK
  (`acssmc-1.1.4.jar`, `com.acs.smartcard.Reader`) via JNI;
  `open()` scans first supported USB device, `waitForCardPresent()` polls `Reader.power(CARD_WARM_RESET)` for ATR,
  `transmit()` via `Reader.transmit()`
- `FutronicPcScHelper.java` — Java helper: `UsbManager` device scan, 500 ms polling loop, 512-byte response buffer

---

### `d0f3eb1` — Add QI card read ops to BprPcSc Sunmi backend, eliminate BprQiEmv JNI dependency
Moved all APDU/QI card reading logic into `backend_android_sunmi.cpp` (previously required
calling out to the separate `BprQiEmv` native lib).

**New ops added (C++ + JNI):**
- `qi_check_inserted` / `mPosCheckQiCardInserted`
- `qi_read_card_number` / `mPosReadCardNumber`
- `qi_read_smart_id` / `mPosReadSmartId`
- `qi_read_user_name` / `mPosReadUserName`
- `qi_read_user_name_1stgen` / `mPosReadUserName1stGen`
- `qi_read_fp_templates` / `mPosReadFpTemplates`

**New header:** `src/BprPcSc/include/pcsc/qi_ops.h` — defines the QI ops interface

**Build:** Added `NO_MFC` define and `BPR_QiSCR` / `BPR_LICNS` / `BPR_CRYPT` / `BPR_UTILS`
sources to the `SO_Android_Sunmi` target so QI script code compiles without MFC.

---

## Final device support matrix (SO_Android_Multi)

| `DEVICE_*` constant | Device family | SDK used |
|---------------------|---------------|----------|
| `DEVICE_PCSCLITE = 0` | Generic / Samsung | pcscd socket |
| `DEVICE_SUNMI = 1`    | Sunmi P2 A11   | Sunmi Pay AIDL (`sunmi.paylib`) |
| `DEVICE_PAX = 2`      | PAX A9/A910S   | NeptuneLite DAL (`com.pax.neptunelite`) |
| `DEVICE_FEITIAN = 3`  | Feitian F2/F310 | Feitian SDK (`com.ftpos.library.smartpos`) |
| `DEVICE_NEXGO = 4`    | NexGo N86      | NexGo SmartPOS SDK v3 (`com.nexgo.oaf.apiv3`) |
| `DEVICE_WIZAR = 5`    | Wizar Q2       | CloudPOS SDK (`com.cloudpos`) |
| `DEVICE_CIONTEK = 6`  | Ciontek C5     | Ciontek AIDL (`posmanager`) |
| `DEVICE_FUTRONIC = 7` | Futronic F8    | ACS USB Smart Card Reader SDK (`com.acs.smartcard`) |
