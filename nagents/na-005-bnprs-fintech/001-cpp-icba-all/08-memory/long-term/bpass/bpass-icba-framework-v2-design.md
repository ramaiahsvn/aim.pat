# bPass-ICBA TLV-Bitmap Framework — v2 design (DRAFT for review)

> Drafted 2026-05-30 for agent na-005/001 cpp-icba-all.
> Decisions locked with user (2026-05-30): location = NEW code in `src/BprICBA/`;
> compatibility = CLEAN REDESIGN (free to define a better wire format); step = design doc first.
> Status: **signed off 2026-05-30 (proposed defaults adopted); codec implemented + tested.**
> Implementation lives in `bpr.cpp/src/BprICBA/bpass/` (tests 26/26 pass). See that module's README.md.
> Builds on [bpass-bitmap-v1-spec.md]. v2 is the basis for the new ICBA framework.

## 1. Goals
- **Data-driven**: one DE schema/dictionary drives both encode and decode (kill the 15
  copy-paste branches).
- **Extensible**: support > 16 DEs via chained bitmaps (ISO 8583 lineage — fits the platform's
  DE numbering model).
- **Standards-aligned**: BER-TLV length encoding (EMVCo / ISO 7816-friendly), ISO/IEC 24787
  (on-card biometric) awareness.
- **Bounds-safe**: a cursor/reader with checked reads; no raw `substr`; typed error results.
- **Structured**: bytes ⇄ `BpassRecord` object; presentation (legacy `+;,` string) is a
  separate optional serializer.
- **Cross-platform C++17**: no Windows-only deps in the codec core (addresses the agent's
  standing "extend beyond Windows" action). COM/glog stay in the BprICBA shell, not the codec.
- **ICBA-first**: carries on-card-biometric semantics (modality, template format + matcher
  version) as first-class header data; biometric templates never leave the card boundary
  (guardrail) — the codec works on references/handles where possible.

## 2. Wire format (v2 — clean redesign)
```
+----------------------------------------------------------+
| HEADER                                                   |
|   Magic   : 1B  0xBP-ish marker / format id              |
|   Version : 1B  (replaces Tag-40; major.minor nibbles)   |
|   Bitmap  : N×1B  chained — b8 of each byte = "another    |
|             bitmap byte follows"; b7..b1 = DE present bits|
|   ModVers : K×1B  per-modality [T|M] version bytes, only  |
|             for biometric DEs flagged present             |
+----------------------------------------------------------+
| BODY: for each present DE in canonical order             |
|   [Tag:1B][BER-Len:1–3B][Value]                          |
|   BER-Len: <0x80 ⇒ 1B; 0x81 xx ⇒ 1B len; 0x82 xx xx ⇒ 2B |
+----------------------------------------------------------+
```
Notes vs v1:
- **Unified BER-TLV length** replaces the split "1-byte for 41–48 / version+2-byte for 49–4F"
  scheme. One rule for all DEs; large biometric payloads use 0x82.
- **Modality version moves into the header** (`ModVers`), so DE values are pure payload
  (cleaner than v1's inline version byte). Mapping: each biometric DE present ⇒ one ModVers byte
  in canonical modality order (Face, FP, FPCless/Knuckle, Palmprint, Iris, OtherBio).
- **Chained bitmap** removes the 16-DE cap.

## 3. DE schema (data-driven dictionary)
A static table; each entry:
```
struct BpassDeDef {
    uint8_t     tag;            // 0x41..
    const char* name;          // "UID","PAN",...
    Category    category;      // Identity | Emv | Biometric
    ValueFormat format;        // NumericHex | Alnum | RawHex
    uint16_t    minBytes, maxBytes;
    Modality    modality;      // None, or Face/FP/... for biometrics
};
```
Seeded from the v1 DE table (tags 41–4F). New DEs = append rows; no parser changes.

## 4. Core API (proposed, header-only-ish core)
```
namespace bpass {
  enum class Category { Identity, Emv, Biometric };
  enum class Modality { None, Face, Fingerprint, FpClessKnuckle, Palmprint, Iris, Other };
  enum class ValueFormat { NumericHex, Alnum, RawHex };

  struct Element { uint8_t tag; std::vector<uint8_t> value; uint8_t tVer=0, mVer=0; };

  class Record {                       // structured, typed accessors
    bool has(uint8_t tag) const;
    const Element* get(uint8_t tag) const;
    void set(uint8_t tag, std::vector<uint8_t> value, uint8_t tVer=0, uint8_t mVer=0);
    // typed helpers: uid(), pan(), name(), face(), fingers()...
  };

  // Decode/encode — symmetric, total functions returning a Result (no throw on bad input)
  Result<Record>              decode(span<const uint8_t> bytes);
  Result<std::vector<uint8_t>> encode(const Record& rec);

  // Bitmap engine (chained)
  class Bitmap { bool test(int de) const; void set(int de); size_t byteLen() const; ... };

  // Bounds-safe reader (replaces substr)
  class Cursor { Result<uint8_t> u8(); Result<span> bytes(size_t n); bool eof(); ... };
}
```
- `Result<T>` = value or `BpassError{code,message,offset}` (no exceptions across the codec
  boundary; the BprICBA C-ABI shell maps errors to existing `errorCode` ints).
- Legacy compatibility: a separate `legacy::toDelimitedString(const Record&)` reproduces the
  v1 `+ ; ,` output for callers that still expect it (kept out of the core).

## 5. Proposed files under src/BprICBA/ (new)
```
BprICBA/
  bpass/
    bpass_schema.h/.cpp     DE dictionary (tags 41–4F + extension rows)
    bpass_bitmap.h/.cpp     chained bitmap engine
    bpass_cursor.h          bounds-checked reader
    bpass_codec.h/.cpp      decode()/encode() over schema
    bpass_record.h/.cpp     Record + typed accessors
    bpass_legacy.h/.cpp     v1 delimited-string serializer (compat)
  tests/
    bpass_codec_tests.cpp   round-trip + spec vectors + fuzz/malformed
```
Crypto/QR (GP key derivation, `bpass_encrypt_decrypt`) stays in BprQR and is called by the
BprICBA shell; the codec is crypto-agnostic (operates on already-decrypted bytes).

## 6. Open design questions (for review)
1. **Magic/version byte**: keep a Tag-40-style marker, or a fixed magic + version byte? (proposed: magic+version)
2. **Bitmap style**: chained ISO-8583 (b8 = continuation) vs a length-prefixed bitmap? (proposed: chained)
3. **BER-TLV vs keep v1 split lengths**: clean redesign favors BER-TLV — confirm.
4. **Biometric template handling under ICBA guardrail**: should the codec ever hold raw
   template bytes, or only opaque handles/refs (templates stay on-card)? Affects Element.value type.
5. **Endianness / hex-string vs raw bytes**: v1 works on hex strings; v2 core should work on
   raw bytes with hex only at the edges — confirm.
6. **Migration**: any need to read existing v1 records, or is v2 greenfield only?

## 7. Out of scope (this step)
No C++ implementation yet. After design sign-off → implement codec + tests (task-001.2),
then wire into BprICBA encode/decode entry points (task-001.3).
