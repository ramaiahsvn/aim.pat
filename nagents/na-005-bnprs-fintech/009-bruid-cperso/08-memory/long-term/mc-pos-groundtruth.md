# MC POS Ground-Truth — working card vs our card (KEEP until MC txn succeeds)

Source: `_Pid1673_Tid0.txt` (Sunmi EMVOptBinderV2, same terminal, back-to-back).
Both transactions SELECT MC AID `A0000000041010`. Use this as the reference checklist for
every re-perso until a live MC sale completes.

## Where our card fails
`emvOptImpl.emvReadAppData ---> code:-4108` ("data of card returns error") — at **READ
APPLICATION DATA**, i.e. BEFORE GENERATE AC. So GEN-AC/terminal tags (9F26 9F27 9F10 9F36
95 9A 9C 5F2A 9F02 9F03) are NOT the cause; the card never reaches that step.
The working card at the same step returns `读应用数据…: 0` (success) and proceeds.

## TLV diff (parsed from each card's READ RECORD responses)
| tag | OUR card (-4108) | WORKING card (ok) | note |
|-----|------------------|-------------------|------|
| 5A (PAN)        | 00…00 (8B)        | 00…00 (8B)        | SAME — both zero; NOT the cause (test terminal ignores PAN content) |
| 57 (Track2)     | all-zeros (19B)   | all-zeros (19B)   | SAME — both zero; NOT the cause |
| **5F25 (Eff date)** | **len 0 (EMPTY)** | **len 3 = 260301** | ⚠️ ROOT CAUSE — 0-length date = malformed → -4108 |
| 5F20 (name)     | "ABD ABD ABD"(11) | "HASSAN/…" (26)   | value only (not fatal) |
| 5F24 (expiry)   | 360231            | 310331            | both valid |
| 8E (CVM list)   | len20             | len14             | different rules, both valid |
| 8F (CAPK idx)   | 08                | EF                | different CA index (issuer-specific) |
| 90 (Iss cert)   | 224B (CA 1792)    | 248B (CA 1984)    | different CA key size — both internally consistent |
| 92 (Iss remnd)  | 4B present        | absent            | key-size dependent — OK |
| 9F46 (ICC cert) | 192B (Iss 1536)   | 176B (Iss 1408)   | different issuer key size — OK |
| 9F48 (ICC remnd)| absent            | 42B present       | key-size dependent — OK |
| 61 (app tmpl)   | absent            | present           | dir-entry from another record — not app-record mandatory |
| 82 94 5F34 8C 8D 9F07 9F08 9F0D/E/F 5F28 9F32 9F42 9F47 9F49 9F4A | present | present | identical/equivalent |

## Verdict
NOT a missing mandatory tag — all mandatory static tags present, ODA cert chain
length-consistent on both. The ONLY structural malformation unique to our failing card:
**5F25 emitted with length 0** (our DPI had no effective date → engine wrote `5F25 00`).
The working card carried a valid 3-byte 5F25.

## Fix applied
`bpr.cpp` `src/BprCardEmv/persoengine/src/sequencer.cpp` (commit 0351912): added
`tlv_opt()` — optional tags are omitted when empty (never length-0); applied to 5F25 in
records 0201 (contact) + 0301 (contactless). When a real effective date is supplied the
output is byte-identical to before.

## UPDATE (v2 test, 2026-07-24) — 5F25 was a RED HERRING; real cause = 5F24 invalid date
After the 5F25 omit fix, re-perso'd + re-tested: our record now omits 5F25, but STILL -4108.
Re-diffed ours-now vs working (`_Pid1673_Tid0_v2.txt`). CAPK RULED OUT: the working card ALSO
logs `tag9F22:EF -> 数据库中未找到匹配的CAPK` (no matching CAPK) yet passes read-app-data — so
CA index / CAPK is an ODA concern, not the read-app-data -4108. The real discriminator, UNCHANGED
between BOTH our failing cards but different on the working card, is the EXPIRY:
  - OURS   5F24 = 360231  -> 2036-02-31  (Feb 31 = impossible date)
  - WORKING 5F24 = 310331 -> 2031-03-31  (valid; March HAS 31 days -> slipped through)
Root cause: engine hardcoded day 31 (`orchestrator.cpp` expiry_yymmdd, `perso-bureau/main.cpp:190`,
`perso-live-visa/main.cpp:66` all did `yymm + "31"`). A strict Sunmi EMV L2 kernel VALIDATES the
calendar date and aborts READ APPLICATION DATA with -4108 on an impossible date.
FIX (bpr.cpp 4926599, bureau sha e7fe1e70): `seq::expiry_5f24(yymm)` -> YYMMDD with the real
last-of-month day (Feb 28/29 leap-aware via yy%4==0 in the 20YY range; Apr/Jun/Sep/Nov=30; else 31).
Unit-verified: 3602->360229, 3604->360430, 3702->370228, 3612->361231. Applied at all 3 sites.
The 5F25-omit change stays (correct: never emit a 0-length date) — it was not the blocker.

## Post-(-4108) flow analysis (v2 log, working card traced end-to-end)
The "working" MC card does NOT approve on this UAT terminal either — it just has no card-data error:
  read-app-data:0 -> CVM online PIN (输PIN结果:0) -> GENERATE AC 9F27=80 (ARQC, card requests ONLINE)
  -> importOnlineProcStatus status:-1, tags 71,72,91,8A,89 EMPTY -> finalStatus -20003 (no acquirer host).
So the online -20003 is an ENVIRONMENT/host failure, not a card failure. Realistic success for our card
after the 5F24 fix = reach GENERATE AC + online request (parity with the working card), NOT "approved".
Non-blockers CONFIRMED (don't chase): (a) ODA/CAPK — terminal has NO matching CAPK for either card
(ours 8F=08, working EF), logs "not found, skip", proceeds; (b) 5F25 absent — optional, not the -4108
trigger, processing-restrictions skips when absent; (c) zero chip PAN — BOTH cards have 5A/57=0 in the
chip (working card's displayed PAN 5222490717837466 came from its magstripe), did not block the working
card's EMV flow. Residual unknown: our card's GENERATE AC (AC keys 8000 etc.) is not exercised by the
local self-verify (only SELECT/GPO/PIN) — only a card test confirms it; expected fine (proven M/Chip key
perso). FOR A REAL APPROVED SALE: real DPI (real PAN + well-formed track2) + acquirer host OR OFFLINE
approval config. OFFLINE approval = DEFERRED (user: "we will work later") — card currently requests ARQC.

## MILESTONE (2026-07-24, mPos_88_resp.txt) — perso PROVEN correct end-to-end; now host-side
After the 5F24 fix + real DPI, the card transacts FULLY online: -4108 GONE; real PAN 5213720978824550;
well-formed track2 (FLD35=5213720978824550D36022011419193800000F, has 0xD); valid GENERATE AC (FLD55:
9F26 ARQC, 9F27=80 ARQC, 9F36=0005 ATC, 9F10 IAD=0110A00003220800...FF -> DKI=01 CVN=0x10, 9F02 amount,
9A=260724, 9C=00). Terminal reached a REAL host 185.206.80.23:1351, sent 0200, got 0210 FLD39=88 (decline).
88 is switch-specific (NOT ISO). Host private FLD63 embeds "92" (ISO 'issuer/FI cannot be found for
routing') -> most likely the BIN 521372 / PAN is NOT provisioned+routed to an issuer host (so the ARQC
was never validated). Alt cause = ARQC key mismatch (issuer HSM lacks our IMK-AC at DKI 01). => ISSUER/HOST
side now, NOT card/perso. Handoff: (1) provision PAN 5213720978824550 + route BIN 521372 to an issuer host;
(2) confirm response 88 meaning + whether ARQC validated; (3) our side confirm perso IMK-AC (keystore
label/DKI 01) matches issuer master key. Card-data/perso work is DONE for MC contact.

## Still-open / watch on re-test (ground-truth checklist)
1. Re-perso a card (over OMNIKEY, transport=pcsc) with the fixed engine → confirm the 0201
   record no longer contains a 0-length 5F25 (either absent, or a valid 3-byte date).
2. Prefer a REAL DPI (real PAN + well-formed track2 with the 0xD separator) so the produced
   card is a proper cardholder card — though zero PAN/track2 did NOT block the working card.
3. Tap at POS → expect read-app-data to pass (no -4108); then watch ODA + GENERATE AC.
4. If a NEW -4108 or later error appears, re-diff against this working card and update this file.
