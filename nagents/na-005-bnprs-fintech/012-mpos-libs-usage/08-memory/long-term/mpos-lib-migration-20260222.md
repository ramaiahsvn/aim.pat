# Work Log — mPos.Lib Migration

## Objective
Remove the old card-reading path (`mPosXxxController` → `ContactCardImpl` → qiemv/qiScript native lib)
and replace it with the new path (`PcscCardReader` → `BprPcSc` native lib), matching the structure already
done in the `sunmi.11.2` module.

---

## Scope — 6 migrated device modules
`pax`, `feitian`, `wizar`, `nexGo`, `ciontek`, `futronic`

Not in scope: `hyf`, `idemia` (not yet migrated, their files untouched).

---

## Completed — Library module changes

### Files deleted from each of the 6 device library modules

| Module   | Deleted file(s) |
|----------|-----------------|
| pax      | `a9services/ContactCardImpl.java` |
| pax      | `a9controller/mPosA9Controller.java` |
| pax      | `com/pax/demo/` tree: `IccTester.java`, `Convert.java`, `IApdu.java`, `IPacker.java`, `Packer.java`, `PackerApdu.java` (PAX NeptuneLite ICC helpers, only used by ContactCardImpl) |
| feitian  | `f2services/ContactCardImpl.java` |
| feitian  | `f2controller/mPosF2controller.java` |
| wizar    | `q2services/ContactCardImpl.java` |
| wizar    | `q2controller/mPosQ2Controller.java` |
| nexGo    | `n86services/ContactCardImpl.java` |
| nexGo    | `n86controller/mPosN86controller.java` |
| ciontek  | `c5services/ContactCardImpl.java` |
| ciontek  | `c5controller/mPosC5controller.java` |
| futronic | `f8services/ContactCardImpl.java` |
| futronic | `f8services/FutronicCardReadingImpl.java` (tightly coupled to ContactCardImpl via mutual static imports) |
| futronic | `f8controller/mPosF8controller.java` |

### Files kept (still active)
- All `*/controller/Listeners/` and `*/controller/interfaces/` listener interfaces — used by new `PcscCardReader` callbacks
- `mPosN86Listner.java` (nexGo) — still referenced by nexGo `FingerprintImpl`
- All `*/services/FingerprintImpl.java` — fingerprint capture, independent of card reading
- All `Utils/`, `network/`, `config/` directories

---

## Completed — Test app changes

### pax/app — MainActivity.java ✅
- Replaced `mPosA9Controller` with `PcscCardReader` + `FingerprintImpl(ctx, dal)`
- `dal` obtained from `NeptuneLiteUser.getInstance().getDal(ctx)` (still needed for FingerprintImpl)
- Card reads use pax separate listener interfaces (lambdas)
- FP capture via `fingerprintImpl.capture(FpCaptureListener)`
- Removed: verify offline/online (controller no longer available), `startCardDetection`

---

## Pending — Test app changes

### feitian/app — MainActivity_F2.java ⏳
- Plan: activity keeps `implements mPosF2Listner` (needed by FingerprintImpl + PcscCardReader)
- Keep `ServiceManager.bindPosServer()` for Feitian SDK init
- Create `PcscCardReader` + `FingerprintImpl(ctx, this)` inside `onSuccess`
- Remove: `mPosF2controller`, `ContactCardImpl contactService`, `IcReader icReader`

### feitian/app — LoginActivity.java ⏳
- Plan: activity keeps `implements mPosF2Listner`
- Create `PcscCardReader` + `FingerprintImpl(ctx, this)` directly (no ServiceManager needed here)
- Remove: `mPosF2controller`, `ContactCardImpl contactService`
- onFpCapture: store bitmap; remove old verify offline call

### wizar/app — MainActivity_Q2.java ⏳
- Plan: activity keeps `implements mPosQ2Listner`
- Create `PcscCardReader(this)` + `FingerprintImpl(this, this)` directly (no ServiceManager)
- Remove: `mPosQ2Controller`, `ContactCardImpl contactService`, `_mParams` string
- FP via `fingerprintImpl.open()` + `fingerprintImpl.capture()`

### wizar/app — LoginActivity.java ⏳
- Same approach as wizar MainActivity_Q2
- Remove old verify offline call in `onFpCapture`

### nexGo/app — MainActivity.java ⏳
- Plan: activity keeps `implements mPosN86Listner` (needed by FingerprintImpl)
- Create `PcscCardReader(this)` + `FingerprintImpl(this, this)`
- Card reads use nexGo functional listeners (single-param callbacks)
- FP via `fingerprintImpl.openDevice(CaptureBmpListener)`
- Remove: `mPosN86controller`

### ciontek/app — MainActivity.java ⏳
- Plan: activity keeps `implements mPosC5Listner`
- Create `PcscCardReader(this)` + `FingerprintImpl(this, this)`
- Card reads pass `this` to PcscCardReader methods
- Remove: `mPosC5controller`

### futronic/app — MainActivity.java ⏳
- Plan: activity no longer implements `mPosF8Listner` (fp capture is commented out in futronic)
- Create `PcscCardReader(this)` only
- Card reads use futronic functional interfaces (from `f8controller/interfaces/`)
- Remove: `mPosF8controller`, `static import mPosF8controller.ansiiso`
- FP capture button: disabled/empty (no fp available for futronic)

---

## Architecture Reference

### New card-reading path
```
PcscCardReader  →  pcsc.java (mPos.Core)  →  BprPcSc.so  →  PC/SC device driver
```

### Old card-reading path (removed)
```
mPosXxxController  →  ContactCardImpl  →  qiemv/qiScript .so  (DELETED)
```

### FingerprintImpl constructors (per device)
| Device   | Constructor                              | Capture call              |
|----------|------------------------------------------|---------------------------|
| pax      | `FingerprintImpl(Context, IDAL)`         | `capture(FpCaptureListener)` |
| feitian  | `FingerprintImpl(Context, mPosF2Listner)`| `open()` + `capture()`    |
| wizar    | `FingerprintImpl(Context, mPosQ2Listner)`| `open()` + `capture()`    |
| nexGo    | `FingerprintImpl(Context, mPosN86Listner)`| `openDevice(CaptureBmpListener)` |
| ciontek  | `FingerprintImpl(Context, mPosC5Listner)`| `open()` + `capture()`    |
| futronic | N/A — FingerprintImpl entirely commented out | N/A                  |
