# Visa POS Ground-Truth — offline decline analysis (KEEP until Visa txn succeeds)

## KEY FINDING (2026-08-16) — the 6A88 is a WRONG DGI LAYOUT, and MC shows the right one
Prompted by "we have keys already; check how we did for MasterCard." Two things settled it.

**What keys we actually have** (`keys/uat_keystore.txt`, labels only): ISD-KVN01, MC IMKs
(IMK-AC/SMI/SMC), **Visa IMKs (VISA-IMK-AC/SMI/SMC)**, DEKs. These are all SYMMETRIC. The
VISA-IMK-AC (KCV 944A44) is the **ARQC/online** key — we have it, so the online path is fully keyed.
There is **NO issuer RSA private key** in the keystore. So "we have keys" = the Visa IMKs; do NOT
re-ask the issuer for those.

**MC does NOT use a real issuer RSA key either — it self-generates one.** `build_mc_cert_key_data`
(orchestrator.cpp) calls `oda::generate_rsa_keypair` for CA/issuer/ICC and self-signs the chain,
exactly like the Visa path does. MC's cert chain is UAT-self-signed and MC still transacts online:
the terminal has no matching CAPK for the self-gen CA, logs "CAPK not found, skip", and goes online
where the ARQC authenticates. **So we do NOT need a real issuer RSA key to clear "ICC data missing"
— we need the certs to LOAD onto the card.** They don't, and here is why:

**The DGI layout is home-grown and INVERTS the manual's distribution.** VSDC 2.9.2 manual, "Tag
distribution — VISA common Personalization specification recommends":
```
DGI 0101 (SFI1 r1): 57 Track2, 5F20 Name, 9F1F Track1-disc
DGI 0201 (SFI2 r1): 90  Issuer PK Certificate          <-- ISSUER CERT LIVES IN 0201
DGI 0202 (SFI2 r2): 9F32 exponent, 92 remainder, 8F CA-index
DGI 0203 (SFI2 r3): 93  SSAD (SDA only)
DGI 0301 (SFI3 r1): 5A PAN, 5F34 PSN, 8E CVM, 9F0D/E/F IAC, 5F24, 5F28, 9F07, 5F25
DGI 0302 (SFI3 r2): 9F4A SDA-tag-list, 8C, 8D, ... 9F08
```
Our engine (orchestrator.cpp `visa_dgis`) does the OPPOSITE:
- 0201 (SFI2 r1) = PAN/expiry/PSN/track2/name/CVM/AUC/IAC   ← should be the ISSUER CERT
- 0301 (SFI3 r1) = the issuer-cert block when fullOda=true   ← should be PAN/CVM/AUC
- 0101 (SFI1 r1) = a 4F/50/9F12/87 DIRECTORY entry           ← should be track2/name
SFI2 and SFI3 roles are essentially SWAPPED, and SFI1 holds the wrong thing. Stuffing the
certificate into 0301 — a record the applet expects to hold PAN/CVM — is almost certainly the
**6A88**. (It is not a length problem — checked: our 1792-bit CA cert encodes to 254 bytes, one
command. And MC proves a ~251-byte cert record loads fine when it goes in the RIGHT DGI.)

**Why MC works and Visa doesn't, in one line:** MC loads its self-gen cert chain via M/Chip's OWN
cert DGIs — `0404` (issuer cert 90+92), `0402` (8F+9F32), `0401/0403` (ICC cert 9F46/9F47/9F48),
`A004` (key-length alloc) — i.e. it FOLLOWS the applet's perso spec. Visa uses an invented
[SFI][rec] layout that contradicts the VSDC applet's spec.

### The real fix (mirrors MC; needs NO external key)
Re-map the Visa records to the manual's distribution: issuer cert → DGI 0201, exponent+92+8F → 0202,
ICC cert → its record; PAN/CVM/AUC/IAC → 0301/0302; track2/name → 0101. Fix the AFL to match. Enable
fullOda. Self-gen keys are fine (as for MC). Expected result: chain LOADS → "ICC data missing" (TVR
bit 3) clears → becomes "ODA not performed" (terminal still has no CAPK) — the SAME state MC
transacts in, so the issuer may accept it exactly as the MC issuer does.

### RISK — why this was NOT blind-deployed
It is a full record + AFL re-layout of a CURRENTLY-WORKING online perso. Get the AFL wrong and the
terminal can't read PAN/track2 → the card fails to read (a wasted tap, worse than today's clean
online decline). The manual's example is "not a real profile" and the recommended table is
abbreviated (no explicit ICC-cert record). This needs careful construction + card validation, which
could not be done from here (kiosk remote, no reader on pat-m4p). Surface for a go/no-go, and decide
against the quick alternative below.

### Quick alternative (non-conformant DIAGNOSTIC) — drop the DDA claim
Set the contact AIP 3800 → 1800 (CVM + TRM, no DDA). Terminal performs no ODA → "ICC data missing"
never set → card authorizes on the ARQC alone (keys we HAVE). One-value change, low risk, isolates
"does the online path work end to end". NOT profile-conformant (production must be 3800 + certs), so
it proves the path, it does not ship a real card.

## HOST DECLINE 05 "Chip Data missing — TVR Bit 3" (after the ATC reset) — ROOT CAUSE FOUND
Progress ladder so far: AUC fix cleared the OFFLINE decline → card goes ONLINE → ATC reset cleared
the ATC-replay decline → now the ISSUER declines on the TVR.

**"TVR Bit 3" = TVR byte 1 bit 0x20 = "ICC data missing"** (numbering the 40 TVR bits from the MSB
of byte 1: bit1 = 0x80 ODA-not-performed, bit2 = 0x40 SDA failed, **bit3 = 0x20 ICC data missing**).
Our measured TVR was **2880808000**, byte 1 = **0x28** = 0x20 (ICC data missing) + 0x08 (DDA failed).
So the host is declining on a bit our card has set all along. It never caused a TERMINAL decline
because those bits sit in TAC/IAC-**Online**, not Denial — which is exactly why the terminal was
happy to go online and the issuer is not.

**Cause:** the card claims DDA in the AIP (`82 = 3800`, bit 0x20 = DDA supported — the profile's
mandated value) but carries **no ODA certificate chain at all** (`8F`, `90`, `9F32`, `92`, `9F46`,
`9F47`, `9F48` all absent, `fullOdaCertChain = false`). A card that advertises DDA and then supplies
no certificates is exactly "ICC data missing". Dropping the DDA claim is NOT the fix — the profile
mandates AIP 3800 and the host is provisioned for a DDA-capable card. **The fix is to ship the
certificates.**

### ⚠️ CORRECTION (same day) — the length theory below does NOT explain our 6A88
I claimed the 6A88 was our Lc truncation on an oversized DGI. **Checked, and it does not hold at our
key sizes.** With the test CA at 1792 bits the issuer certificate (tag 90) is 224 bytes, so
`8F+90+9F32+92+9F49+9F4A` = 248, `tlv(70,…)` = 251, and DGI 0301 encodes to **254 bytes — one
command, no span.** The manual's example spans only because its CA is 1984-bit (248-byte cert → 262).
So:
- The spanning support is **correct and mandated** (VSDC 2.9.2 §4.4) and is needed the moment we
  move to a real 1984-bit CA — keep it, along with the Lc guard that stops silent truncation.
- **It is not the cure for the 6A88, and enabling fullOda will not obviously fix anything.**
  The cause of the 6A88 on DGI 0301 remains UNKNOWN.
- Corroboration that record size is not the issue: our **MC** cards already ship a full chain at the
  same sizes (`CA1792 → Iss1536 → ICC1152`, with `8F 90 92(4B) 9F32 9F46 9F47` all present on the
  card — see the -4108 analysis in `knowledge.yaml`). So a ~251-byte ODA record is loadable in
  practice; whatever fails on the Visa applet is Visa-specific and still undiagnosed.

### ⚠️ THE TERMINAL CANNOT VERIFY ODA AT ALL — POS-side bug, already recorded
`knowledge.yaml` (2026-07-24) captured this and it was never closed:
> CAPK load CRASHED — `hexStr2Bytes StringIndexOutOfBounds length=495 index=495` (odd-length CAPK
> hex) in `CAPKsLoader.syncCAPKsToEMVKernel` → **NO CAPKs loaded into kernel**

That is a POS/ITP config bug, not our card. **With no CAPK in the kernel the terminal cannot verify
any certificate chain we ship**, so loading ODA would most likely turn TVR bit 3 (0x20 "ICC data
missing") into bit 1 (0x80 "offline data authentication was not performed") rather than clearing the
decline. **Ask the issuer which bit they actually gate on before spending a card** — if they decline
on "ODA not performed" too, no card-side change helps until the POS CAPK table is fixed AND we hold
a real issuer certificate under a CA the terminal carries (the long-outstanding bureau ask,
`rnd-cperso 2026-07-15-issuer-rsa-key-process.md`).

### Original (partly wrong) reasoning, kept for the trail
The deferral note says "loading the cert into 0301 currently returns 6A88 → keep OFF until the
applet's ODA record spec is confirmed". Two findings kill that reading:

1. **`[SFI][rec]` DGIs are valid for ANY SFI 1-30** (VSDC 2.9.2 manual, "DGIs supported by applet":
   *"For readable records in any file with SFI in the range 1-30 … data should be embedded within
   template 70 in TLV format"*). DGI 0301 was never unsupported.
2. **The real blocker is that a 248-byte issuer certificate cannot fit in one STORE DATA command,
   and our Visa path cannot split it.** Manual §4.4 "Long data loading" is explicit:
   > "EMV CPS allows to load data with one DGI spanned on 2 STORE DATA command. **It is mandatory
   > to support such a feature to load 248 bytes Issuer Public Key certificate (tag 90).**"
   > "The VISA implementation on VSDC2.9.2 applet requires that **DGI length be always coded on 3
   > bytes when a DGI is spanned on 2 STORE DATA command.**"

   Worked example from the manual — one DGI, two commands, P2 increments per COMMAND:
   ```
   CMD: 80E2 00 08 FF  0201 FF00FE 70 81fb 90 81f8 <…248-byte cert…>   STATUS: 9000
   CMD: 80E2 00 09 04  8E79628D                                        STATUS: 9000
   ```
   (DGI data = 254 bytes, total encoded = 2+3+254 = 259, sent as 255 + 4.)

**Our code cannot do this.** `orchestrator.cpp` (Visa STORE DATA loop) builds exactly one APDU per
DGI with `Lc = static_cast<uint8_t>(dgi.size())` — for a 259-byte DGI that **silently truncates to
Lc = 3**, producing a malformed command the applet rejects with a confusing SW. That misleading SW
is what got recorded as "the applet does not support this DGI".
Note the MC path is safer but no more capable: `sequencer::build_store_data_apdus` **throws**
`"STORE DATA block exceeds 255 bytes"` rather than truncating, so MC fails loudly. Neither scheme
can currently load a spanned DGI.

### The fix (three parts, all in our code — no vendor input needed)
1. **Split any encoded DGI > 255 bytes across two STORE DATA commands** — first carries 255 bytes,
   second the remainder — with **P2 incrementing per command, not per DGI**.
2. **Force the 3-byte `FF <len16>` DGI length whenever the DGI will be spanned**, even when the data
   length would fit in one byte (the manual's own example uses `FF00FE` for 254). `encode_dgi`
   currently uses the 3-byte form only at `size >= 0xFF`, so it needs a "spanned" flag.
3. Keep the end-of-perso `P1 |= 0x80` on the **final command overall** — i.e. the second half of a
   split last DGI, not the first.
Then set `fullOdaCertChain = true` and re-perso. Also add the missing `Lc` guard to the Visa loop so
an oversized DGI can never again be silently truncated into a misleading card error.

### Watch on re-test
- Expect TVR byte 1 to lose 0x20 (and 0x08 if DDA actually verifies). ODA also needs the terminal to
  hold a CAPK for our `8F` index — the logs show `数据库中未找到匹配的CAPK` (no matching CAPK), so
  with a TEST CA the terminal may instead set bit1 0x80 "ODA not performed". **Confirm with the
  issuer which they check**: if the host declines on "ODA not performed" too, we need a real
  issuer certificate under a CA the terminal already carries, not our UAT test CA.
- That question is worth asking BEFORE spending a card, since it decides test-CA vs real-CA.

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
