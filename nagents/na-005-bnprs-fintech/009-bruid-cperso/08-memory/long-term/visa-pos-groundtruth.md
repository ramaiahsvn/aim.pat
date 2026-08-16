# Visa POS Ground-Truth — offline decline analysis (KEEP until Visa txn succeeds)

## RE-TEST 2026-08-16 09:28 — AUC FIX CONFIRMED WORKING. Three things remain.
Source: `VISA IC without PIN and Cless issue.txt` (Pid=6432), same card 4177630226449323.

**CONFIRMED FIXED — the offline decline is gone.** The card's 0201 record now reads
`9F07 02 FF80` (was C080). Kernel diag DF816F gives **TVR = 2880808000** — byte 2 is 0x80, the
**0x10 denial bit is GONE** (only the harmless app-version-mismatch bit remains).
`TVR & (TAC|IAC)-Denial = 0` → no decline. `emvTaa code:2` (go online, was `-4000`).
GENERATE AC went out as **P1=0x80 (ARQC)** and the card returned **CID=0x80 = ARQC**, ATC=0008,
IAD `06 01 0A 03 A090000F04…` → DKI=01, **CVN=0x0A (CVN 10)**. Card side is complete for online.

### Issue 1 — NO PIN (regression caused by the July CVM change)
`9F34 = 3F 00 01` = "No CVM required", condition always, **successful**. The terminal SKIPPED our
first CV rule and fell through to the No-CVM fallback, so no PIN was requested.
Our list is `8E = 0000000000000000 4103 1F00`: `41 03` = offline **plaintext PIN verified by ICC**,
condition 03 = "if terminal supports the CVM". **This terminal does not support offline plaintext
PIN**, so the rule is skipped and `1F 00` (No CVM) applies.
Proof the terminal DOES support **online** PIN: (a) the reference Visa card, whose list leads with
`02` (enciphered PIN verified ONLINE), prompts for PIN on this terminal; (b) our own card in the
July trace, when it still had the online-PIN list, produced TVR byte 3 = 0x04 = "Online PIN entered".
=> The July CVM change — made to fix a decline it never caused (see the correction below) — is what
removed the PIN.
**FIX = restore the issuer profile's CVM list verbatim: `8E = 0000000000000000020542035E031F02`**
(online PIN if cashback / online PIN if terminal supports / signature / No-CVM). This is the
approved product value, confirmed against the VPA profile XML — see [[visa-profile-conformance]].
It is exactly what the card carried BEFORE the July change.
(An earlier note here proposed an invented list `000000000000000042031F00`. That is SUPERSEDED —
do not invent a CVM list when the profile specifies one.)

### Issue 2 — ONLINE step returns nothing (host/app side, NOT the card)
`importOnlineProcStatus status:-1`, tags `71,72,91,8A,89` all EMPTY → `finalStatus -20003` →
`CVM处理出错 errCode:-50024`. Identical signature to the MC environment failure recorded in
[[mc-pos-groundtruth]] ("no acquirer host"). The card produced a valid ARQC; nothing usable came
back from the host. Issuer/acquirer side: the host must validate a **Visa CVN10** ARQC with our
Visa IMK-AC (KCV 944A44) at DKI 01. Note magstripe with this same PAN DOES succeed, so routing is
fine — this is ARQC validation / response plumbing, not routing.

### Issue 3 — CONTACTLESS IS DEAD: the card has no PPSE
Contactless tap (`EMVPayWaveHelperV2`): `SELECT 2PAY.SYS.DDF01` → **6A82 (file not found)**, then a
handful of AIDs → all 6A82, then `emvAppBuildList code:-4106` (candidate list empty). DF816F ends
`…016A8200…`.
Root cause: **our cards carry neither PSE (1PAY) nor PPSE (2PAY)**. The engine DELETES both
directories in the MC perso-entry (`orchestrator.cpp:573`, and `perso-live/main.cpp:313`,
`perso-dryrun` steps 4-5) and **never creates either one**. On CONTACT this is survivable — the
terminal falls back to scanning ~28 AIDs and finds ours — but the contactless kernel discovers
applications ONLY through the PPSE, so with no PPSE the card can never be tapped.
Second, likely-also-required part: the Visa instance must be **activated on the contactless
interface** of this dual-interface GP card (contactless registry / CRS, or INSTALL params that
assign the CL interface). Our INSTALL uses priv `00`, params `C900` — no CL assignment. The qVSDC
perso data itself already exists (DGIs 9115/9117, AIP 0020/2020), so it is discovery + interface
activation that is missing, not the contactless record set.
=> Fixing cless is NOT a one-liner. The vendor's exact recipe is now known — PPSE is a SEPARATE
instance of the VSDC 2.9.2 applet from the StubServer package (A00000000316 / module
A0000000031650), with the literal INSTALL APDUs and the DGI 9102 FCI content — plus the qVSDC GPO
DGIs need their full element set. All of it is written up in [[visa-profile-conformance]].

## CURRENT ROOT CAUSE (2026-08-16) — 9F07 Application Usage Control = C080

Source: `VISA SP logs.txt` (Sunmi pay service, Pid=1778, 2026-08-16, aeonpay terminal).
Two taps captured, both cards SELECT `A0000000031010`:
- 08:02 — **reference card** (name "VISA", magstripe PAN 4177630208260920): operator cancelled
  PIN (`importPinInputStatus inputResult:1` → `-50020`), so it never reached Terminal Action
  Analysis. TVR was still 0000000000. Not a card fault — no verdict from this tap.
- 08:08 — **our cPerso/iPerso card** (5F20 = MOHMMED A. SALMAN, 5F24 = 360331, magstripe PAN
  4177630226449323): `emvTaa code:-4000` → **AAC (offline decline)**, GENERATE AC P1=00,
  card returned CID=00.

### Terminal Action Analysis (from kernel diag tag DF816F, not inferred)
```
TVR        = 2890808000
TAC-Denial = 0010000000   IAC-Denial (9F0E) = 0010000000
TAC-Online = 584000A800   IAC-Online (9F0F) = B8689C9800
TAC-Deflt  = 584000A800   IAC-Deflt  (9F0D) = B8609C8800
TVR & (TAC|IAC)-Denial = 0010000000  -> non-zero -> AAC, checked BEFORE Online.
```
TVR byte 2 = 0x90 = 0x80 (ICC/terminal different application versions) + **0x10 (Requested
service not allowed for card product)**. The 0x10 is the SOLE denial bit.

### Why the bit is set — the one discriminator vs the reference card
Full TLV diff of both cards' READ RECORD data: identical or benign on every tag except

| tag | reference card | OUR card | effect |
|-----|----------------|----------|--------|
| **9F07 (AUC)** | **FF80** | **C080** | ⚠️ ROOT CAUSE |

`9F07 = C0 80` (EMV Book 3 Annex C2) byte 1 = `1100 0000`:
- b8 valid domestic cash = 1, b7 valid international cash = 1
- b6/b5 goods = 0, b4/b3 services = 0
- **b2 valid at ATMs = 0**, **b1 valid at terminals other than ATMs = 0**

With b2 AND b1 both 0 the card is valid at **no terminal type at all**, so EMV Book 3 §10.4.3
sets "Requested service not allowed for card product" on *every* terminal, for *every*
transaction type. Combined with the card's own IAC-Denial `0010000000` this is a double lock:
**our Visa card can never complete a purchase on any terminal.** Reference card `FF80` = valid
for everything → bit never set → passes Processing Restrictions.

### Source of the defect
`bpr.cpp src/BprCardEmv/persoengine/src/orchestrator.cpp:308` — `tlv(0x9F07, from_hex("C080"))`,
hardcoded in the Visa DGI builder since commit `d3d3f97` (2026-07-22, Visa live-perso extracted
into the orchestrator). Not DPI-driven, not configurable.
**Corroboration:** the MasterCard path uses `auc = FF00` (`sequencer.hpp:37`) and MC transacts
online successfully on this same terminal. Same engine, only the Visa AUC is wrong.
Fix = set the Visa AUC to `FF80` (match the reference card) — better, make it profile/DPI-driven
like the MC path instead of a literal.

### CORRECTION to the 2026-07-24 analysis (recorded below) — it was WRONG
The July entry identified the same bit position (TVR byte 2, 0x10) but mislabelled its MEANING as
"PIN entry required, PIN pad not present/working". That is **byte 3** bit 0x10, not byte 2.
Byte 2 bit 0x10 is "Requested service not allowed for card product" (Processing Restrictions / AUC).
Two proofs the CVM theory was wrong:
1. The July TVR `2890048000` has byte 3 = **0x04 = "Online PIN entered"** — the PIN pad was
   present and online PIN was entered successfully. It was never a PIN-pad problem.
2. The CVM fix WAS applied and IS on the card tested 2026-08-16 (`8E = 000000000000000041031F00`,
   offline plaintext PIN + No-CVM), and the card still declines with the same denial bit.
The CVM change is harmless and can stay, but it did not and could not fix this decline.
**Do not spend another card on a CVM variable.**

### Also observed on our card (NOT the decline cause — do not chase)
- **Zero chip PAN/track2** (5A + 57 all zeros): the REFERENCE card has this too, and the terminal
  takes the PAN from the magstripe (service code 201 forces chip use after the swipe). Consistent
  with the MC ground truth. Not a blocker; still worth fixing for a proper card.
- **No ODA certs** (8F/90/9F32/9F46/9F47/9F48 absent, fullOda=false) → TVR byte 1 = 0x28
  (ICC data missing + DDA failed). Those bits are in TAC/IAC-**Online**, not Denial → they route
  the txn ONLINE, they do not decline it.
- **No PSE**: `SELECT 1PAY.SYS.DDF01` → 6A82, so the terminal brute-force scanned ~28 AIDs before
  finding ours. Works, but slow/fragile; the reference card publishes a PSE.
- **9F08 = 00A0** vs terminal 9F09 = 0002 → TVR byte 2 0x80 (different app versions). Not in any
  Denial code → harmless here.
- Absent on ours, present on reference: 5F25, 5F2D, 5F30, 9F11, 9F42, 9F44, 9F1F — all optional.
- SFI 1 rec 1 on our card holds a tag-61 *directory* entry (AID/label), not application data,
  even though the AFL points the kernel at it. Harmless, but it is not what SFI 1 rec 1 is for.

### Expected behaviour AFTER the AUC fix
Denial bit clears → the card passes Terminal Action Analysis → TVR still has floor-limit-exceeded
(0x80 byte 4, terminal `termOfflineFloorLmt=000000000000`) and DDA-failed/ICC-missing, all of which
are in TAC-Online → the card will request **ARQC (online)**, i.e. parity with the proven MC flow.
**Magstripe already transacts successfully with our card**, which proves the PAN/BIN routes and the
acquirer/issuer path is live — so the remaining online question is narrowed to whether the issuer
host can validate our Visa ARQC (Visa IMK-AC, KCV 944A44, at the right DKI). Offline approval
remains impossible on this terminal (floor limit 0) without a terminal-side change.

### STATUS: fix built + deployed 2026-08-16 — next action is to spend ONE card
`VisaPersoConfig::auc` (default `FF80`) now drives 9F07; the `C080` literal is gone. Bureau
rebuilt and live — binary sha256 `f582a042…8cf7`, service active on 9099. Re-perso one Visa card
and re-tap: expect TVR byte 2 to lose the 0x10 bit and the card to request ARQC (online).

### Bureau deploy facts (correct as of 2026-08-16 — earlier notes were stale)
- Instance `i-00eb79ff8e9e1788b` = `perso-bureau-uat`, 98.130.14.127, **ap-south-2b**, t4g.small
  **arm64**, AWS profile **`bnprs`** (891963159778).
- The systemd unit is **`bpr-iperso-bureau.service`**, NOT `perso-bureau` — older memory entries
  say `perso-bureau` and are wrong; `systemctl is-active perso-bureau` misleadingly returns
  "inactive" rather than erroring. Binary + certs + keystore live in `~ubuntu/bureau/`.
- **SSM Session Manager is NOT available** on this box (not registered with SSM, and
  `session-manager-plugin` is not installed locally). Access is SSH via **EC2 Instance Connect**.
- Port 22 is allow-listed to fixed office IPs in `sg-061425921af1f1451`; a roaming IP needs a
  temporary ingress rule. **na-003/001 bnprs-aws guardrail: confirm with the user before modifying
  a security group**, and revoke the temp rule as soon as the deploy is done.
- Instance Connect key window is ~60s and timing-sensitive: `send-ssh-public-key` and the `ssh`/
  `scp` must be chained in ONE command (`&& `), with no subshell or sleep between them.
- Build recipe: `docker run --platform linux/arm64 -v <bpr.cpp>:/src:ro ubuntu:24.04`, deps
  `build-essential cmake libpugixml-dev libssl-dev nlohmann-json3-dev libgtest-dev libgmock-dev`,
  configure with `-DPERSOENGINE_BUILD_TLS=ON -DCMAKE_BUILD_TYPE=Release`, target
  `bpr-iperso-bureau`. Ship ONLY the binary; keep the previous one as `.bak-pre-<change>`.
- `strings` is not installed on the instance — verify the shipped binary by sha256 match against
  the locally verified one (stronger anyway), or `grep -ac`.

---

## SUPERSEDED — 2026-07-24 analysis (kept for the audit trail; root cause was WRONG, see above)

Source: `_Pid1736_Tid0_visa.txt` (Sunmi EMVOptBinderV2, aeonpay, KIOSK-DXB-014).
Card: our perso'd Visa, PAN 4177630223489082, AID A0000000031010 (Visa Debit).

### What happened (NOT the MC issue, NOT an app crash)
Card reads PERFECTLY: `读应用数据: 0` (read-app-data OK), real PAN, name MOHMMED A. SALMAN,
valid 5F24=360331, track2 well-formed. The transaction then **declined OFFLINE**: the terminal
did Terminal Action Analysis and requested **AAC** (`GENERATE AC P1=00`) — it NEVER went online.
Card returned CID=00 (AAC).

### Terminal Action Analysis (computed)
- TVR (95) = **2890048000**
- Card IAC:  Denial 0010000000  Online B8689C9800  Default B8609C8800
- Term TAC:  Denial 0010000000  Online 584000A800  Default 584000A800
- **TVR & (TAC|IAC)-Denial = 0010000000 → DECLINE.**
- ~~The SOLE trigger bit = TVR byte2 0x10 = "PIN entry required, PIN pad not present/working".~~
  **WRONG — byte 2 bit 0x10 = "Requested service not allowed for card product" (AUC). See top.**
- TVR & (TAC|IAC)-Online = 2800048000 (non-zero) → would GO ONLINE, but Denial is checked FIRST.
- The DDA-failed / ICC-missing / floor-limit bits are NOT in the Denial codes → they do NOT cause
  the decline (they route ONLINE). The cert-chain (fullOda) gap is a RED HERRING for this decline.

### ~~Root cause = CVM~~ — DISPROVEN 2026-08-16
Old CVM list (8E) = `0000000000000000 0205 4203 5E03 1F02` led with enciphered PIN verified
ONLINE (0x02). Theory was that an offline transaction cannot do online PIN → TVR "PIN pad not
present/working". Disproven: that bit is byte 3, and byte 3 was 0x04 = "Online PIN entered".

### Fix applied (bpr.cpp orchestrator.cpp:291, bureau sha 9d64613d93455391, deployed 2026-07-24)
CVM list → `000000000000000041031F00` = offline plaintext PIN (0x41, cond 03; card PIN=1234,
self-verify VERIFY→9000) then No-CVM fallback (0x1F, cond always).
Confirmed present on the 2026-08-16 card. Harmless, but it fixed nothing.

### CRITICAL follow-on: this terminal FORCES online (offline approval impossible here)
Term `termOfflineFloorLmt = 000000000000` (floor limit = 0) → EVERY txn exceeds floor → the
"exceeds floor limit" TVR bit (in TAC-Online A8) forces ONLINE. Two paths to an approved Visa sale:
1. ONLINE (mirrors MC): needs a Visa auth host to validate the Visa ARQC. Card side ready; Visa
   path already derives UDK with the card PSN (unlike the old MC bug). [[mc-pos-groundtruth]]
2. OFFLINE approval: POS team must RAISE the terminal offline floor limit AND we drop the AIP DDA
   claim (or ship fullOda=true + load our test CA on the terminal). Then terminal → TC.
