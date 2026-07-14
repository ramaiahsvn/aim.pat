# INPUT → na-005/008 bruid-dprep

**Routed by:** na-100/003 rnd-cperso · **Date:** 2026-07-14 · **Priority:** HIGH · **Status:** OPEN

## UAT IMK keys received + verified — DP is unblocked
Perso bureau delivered UAT keys → `TRP1002_cPerso/trp1002.cperso.thales/Resources/UAT_Keys.txt`
(git-ignored; VALUES stay there, NOT in agent files — labels/KCVs only per PCI).

- **ZMK (transport/KEK):** 3 components; reconstructed **ZMK = P1 ⊕ P2 ⊕ P3**, KCV **`A85DE2`** (verified;
  component KCVs 6DB2A2 / CCC0E4 / E24E54).
- **IMK-AC/SMI/SMC:** delivered ENCRYPTED under the ZMK; decrypt (3DES-ECB under ZMK) → clear IMK,
  KCV **`82E136`** (verified). Note: UAT IMK is single-length-style (K1==K2) — handle the degenerate
  case in KCV/derivation (3DES with K1==K2 == single DES).

## What this unblocks (your task-001.2/001.3)
- **Derive per-card UDK (EMV Option A)** from the IMK (KCV 82E136) + PAN + PSN → the card's AC/SMI/SMC keys.
  Verify each UDK against its KCV. This is the P3a path (already KAT-anchored) — now run it with the real UAT IMK.
- Assemble the DGIs (per EMV CPS: DGI ≥ 0x8000 encrypted under session DEK; key/PIN ordering) and hand to
  cperso/iperso for STORE DATA.

## Bureau's scope note (2026-07-14) — confirm before assuming
Bureau says: for DATA PREP only the IMK is needed; **CVK-A/B, PVK, PIN-TK are transaction/host-side.**
- **PVK** — agreed, host-side (PVV not on card).
- **CVK** — needed at DP ONLY if we compute iCVV/CVV2 (G&D DPI had them EMPTY → maybe we compute). CONFIRM:
  iCVV/CVV2 supplied in DP data vs computed by us.
- **PIN-TK** — needed at DP ONLY if an offline reference PIN is loaded centrally. CONFIRM: offline PIN at DP
  vs online/kiosk-set.
If iCVV/CVV2 are supplied and no offline PIN at DP → IMK alone suffices; else request CVK/PIN-TK.

## Companion key (already held)
SCP02 ISD transport key (KCV C277BA, VISA2 div, KVN01 — value provided out-of-band, NOT stored) — opens the secure channel to the
card for loading (rnd-cperso mem-009). DEK (MENTA, INSTANT channel) still outstanding, out-of-band.

## Action
1. Run UDK derivation with the UAT IMK for a test PAN; verify UDK KCV.
2. Build DGIs; coordinate STORE DATA with cperso (central) / iperso (instant).
3. Feed back the iCVV/CVV2 + offline-PIN DP-scope answers so rnd-cperso can close the CVK/PIN-TK question.
