# bPass TLV-Bitmap — v1 (current) spec + implementation analysis

> Captured 2026-05-30 from `~/Downloads/bPass-TLV-Bitmap.xlsx` (sheet "bPass") and the
> live implementation `bpr.cpp/src/AprCommon/BprQR/bpr_qr_main.cpp::patParseDecodedQRCode`
> (called by `BprICBA::Bpr_QRCode_Decode`). This is the agent's reference copy so it need
> not re-read the xlsx/source each session. Source of truth for code: the repo.

## Format overview
A bPass record = **Header (8 bytes / 16 hex)** + **Body (concatenated TLVs, tags 41–4F)**.

### Header (8 bytes)
- **Byte 1–2 = presence bitmap (16 bits).** Bit set ⇒ that tag's DE is present in body.
- **Byte 3–8 = per-modality biometric version descriptors** (one byte each: Face, FP,
  FPCless/Knuckle, Palmprint, Iris, OtherBio). Each byte = `[T high-nibble][M low-nibble]`:
  T = template-format version, M = matcher version.

### Bitmap bit → tag map
| Byte1 bit | Tag | | Byte2 bit | Tag |
|-----------|-----|--|-----------|-----|
| b8 | 40 (version marker "1.0") | | b8 | 48 NAME |
| b7 | 41 UID | | b7 | 49 EMVTLV |
| b6 | 42 PAN | | b6 | 4A FACE |
| b5 | 43 DOB | | b5 | 4B FINGERS |
| b4 | 44 EXPDATE | | b4 | 4C FPCLESS/KNUCKLE |
| b3 | 45 MOBILE | | b3 | 4D PALMPRINT |
| b2 | 46 PASSPORT | | b2 | 4E IRIS |
| b1 | 47 NID | | b1 | 4F OTHERBIO |

## Body data elements (tags 41–4F)
| DE | Tag | Name | Min B | Max B | Format | Meaning |
|----|-----|------|-------|-------|--------|---------|
| 1 | 41 | UID | 4 | 16 | n…32 Hex LLVAR | smart id / guid |
| 2 | 42 | PAN | 4 | 10 | n…20 Hex LLVAR | account number |
| 3 | 43 | DOB | 4 | 4 | n-8 Hex | date of birth |
| 4 | 44 | EXPDATE | 4 | 4 | n-8 Hex | expiry |
| 5 | 45 | MOBILE | 4 | 8 | n…16 Hex | mobile number |
| 6 | 46 | PASSPORT | 6 | 10 | an…10 LLVAR | passport |
| 7 | 47 | NID | 6 | 12 | an…12 LLVAR | national ID (Aadhaar/eKTP/EID) |
| 8 | 48 | NAME | 6 | 50 | an…50 LLVAR | full name |
| 9 | 49 | EMVTLV | 8 | 256 | an…512 Hex LLVAR | EMV chip data (TLV) |
| A | 4A | FACE | 256 | 512 | an…1024 Hex | face template |
| B | 4B | FINGERS | 256 | 512 | an…1024 Hex | best 2 fingerprint templates |
| C | 4C | FPCLESS/KNUCKLE | 256 | 256 | an…512 | touchless fingers / knuckle |
| D | 4D | PALMPRINT | 256 | 512 | an…1024 | palmprint template |
| E | 4E | IRIS | 256 | 256 | an…512 | two iris codes |
| F | 4F | OTHERBIO | 6 | 256 | an…512 | reserved (future) |

(Min/Max shown in BYTES; the xlsx lists both hex-char count and byte count.)

## Length-encoding schemes (as implemented)
- **Tags 41–48 (identity DEs):** `[Tag:1B][Len:1B][Value]` — 1-byte length (bytes).
- **Tags 49–4F (EMV + biometrics):** `[Tag:1B][VersionByte:1B][Len:2B][Value]`.
  - VersionByte = the T+M modality descriptor; `00` ⇒ DE absent (skip, advance 4 hex).
  - 2-byte length because payloads are large.
- `fpTemplateType = header hex[6]` selects FP template version; value `"2"` = Innovatrics
  ISO templates → Tag-4B is split into multiple fingerprint templates (`,`/`;` delimited).

## v1 implementation weaknesses (motivation for v2 redesign)
1. Not bitmap-driven — sequentially probes all 15 tags; the 16 presence bits aren't decoded.
2. 15 near-duplicate if/else branches; no DE schema/dictionary (copy-pasted substr/len logic).
3. No bounds checking — raw `substr` on malformed input can throw (single outer try/catch).
4. Parse and output formatting intertwined (`+ ; ,` delimiters); output is a delimited
   string, not a structured object.
5. Magic offsets (`substr(6,1)`), hardcoded modality special-cases.
6. Hard cap at 16 DEs — no extension path.
