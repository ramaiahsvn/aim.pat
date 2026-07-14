# Technical Query → Gemalto (Thales DIS) — M/Chip perso-entry mechanism

**From:** BNPRS card R&D (na-100/003 rnd-cperso) · **Date:** 2026-07-14 · **Re:** UAT cards, pre-installed M/Chip applet
**Delivery:** send as HTML email (Segoe UI 15px, per house style) or vendor ticket. Ready to paste below.

---

**Subject:** M/Chip UAT cards — exact personalization-entry command sequence for the pre-installed applet

Hello [Gemalto contact],

Following your earlier confirmation that applet **`A0000000180F0000018330324444`** is the M/Chip
payment applet/instance (Card Manager `A000000004000000`), and that its **`6999`** on SELECT is the
expected installed-but-unpersonalized state — we are ready to personalize the UAT cards and would like
to confirm the **exact entry sequence** to drive `STORE DATA`.

**What we have working**
- Authenticated **GP SCP02** to the ISD (`A000000004000000`), KVN 01, VISA2 key diversification — INIT
  UPDATE → EXTERNAL AUTHENTICATE succeed (`9000`).
- Card keys, EMV data profile, and the full STORE DATA/DGI content are prepared.

**What we have tried to reach the applet for `STORE DATA` — all fail**

| Attempt (inside the authenticated SCP02 session) | Result |
|---|---|
| Plain `SELECT A0000000180F0000018330324444` | `6999` |
| `SELECT` wrapped with C-MAC (CLA 84) | `6E00` |
| `INSTALL [for install & make selectable]` a new instance under `A0000000041010` | instance created, but `6999` |
| `INSTALL [for personalization]` (`80 E6 20`) targeting `A0000000180F0000018330324444` | `6985` |

**Our questions**
1. What is the **exact command sequence** to place applet `A0000000180F0000018330324444` into
   personalization mode and send `STORE DATA`? (Please specify the ordered APDUs.)
2. Is there a **specific perso-SELECT** (particular P1/P2 or a Gemalto perso AID) rather than the ISO
   `00 A4 04 00`?
3. Does the entry require a **specific Security Domain privilege**, a **security level** (we tried C-MAC=01
   and C-MAC+C-DEC=03), or a **key/keyset** other than the ISD KVN 01?
4. Is personalization driven **applet-side** (its own INIT UPDATE / EXT AUTH after a perso-SELECT) or
   **SD-forwarded** (`INSTALL [for personalization]` + `STORE DATA` via the ISD)? If the latter, what
   precondition are we missing (the `6985`)?
5. After personalization, under which **AID does a payment terminal select** the applet — the standard
   `A0000000041010`, or `A0000000180F0000018330324444`? Is the **PPSE (`2PAY.SYS.DDF01`)** populated during
   perso?

For reference, our data-prep + STORE DATA/DGI layout follows EMV CPS and the M/Chip profile; the only open
item is this on-card entry step. A short **APDU trace of a successful perso** of one of these cards from your
tool would answer everything at once, if that is easier to share.

Thank you,
BNPRS Card R&D

---

## Internal notes (do not send)
- Test key = UAT Thales test ISD key (KCV `C277BA`, VISA2, KVN01) — held; not to be quoted to vendor.
- Both UAT cards affected (MC ISD `A000000004000000`; Visa ISD `A000000003000000`, applet
  `A000000018320A02…`). Same question applies to both.
- This is the SOLE gating item; DP/keys/DGI/ODA/PIN all resolved (see mem-009..014). A successful-perso APDU
  trace would also let us finish the P5 Sequencer (bruid-cperso).
