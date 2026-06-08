# EBE UI Parity — Gap Analysis

**Target repo:** `bpr1003.itp.mpos.2.ebe` (ITP mPOS v2, the app being reskinned to EBE)
**Base reviewed:** `origin/bp_dev` @ `d295b6b0` — *Merge `feature/ebe-reskin-p2-p211-q2`* (2026‑06‑07)
**Reference (design source of truth):** `bpr1003.mpos.ebe` — UI in `business/uikit/src/ui/`
**Variant analyzed:** `mPos.F2` (screens are duplicated per variant: F2 / P2 / P2.11 / Q2)
**Method:** static diff of EBE source vs this repo. Theme status detected via presence of `@color/ebe_*` references in each screen's layout.

## Headline
The EBE **theme/colour pass is already in `bp_dev`** (most screens reference `ebe_background`, `ebe_surface`, `ebe_key_ok`, etc.). The reviewer's remaining items are **structural/visual parity** (layout arrangement, specific widgets, borders) plus **missing assets** (icons, Lottie animations) — *not* "apply EBE colours."

> Visual parity is a rendered-screen judgment. This analysis identifies the structural deltas and the exact files; final "matches EBE" sign-off needs the screens viewed on-device.

## Status legend
✅ done · 🟡 theme done / structure pending · 🔴 not updated · ⛔ not present

| # | Item | This-repo file (F2) | EBE source | Status | Risk |
|---|------|---------------------|-----------|--------|------|
| 1 | Amount entry box + keypad | `activity_keyboard_transaction.xml` (0 `ebe_` refs) | `fragment_enter_amount.xml` + `amount_keyboard.xml` | 🔴 not themed | Low (UI only) |
| 2 | Card insert/tap/swipe animations | *none* — no dialog, no Lottie card assets | `LottieFragment` + `assets/drawable/default/{en,ar}/{insert,tap,swipe}_card.json` | ⛔ absent | **High** — hooks EMV `onSearchCard`/callback (payment-critical, needs device test) |
| 3 | Settings password UI | `activity_password_dialog.xml` (already `ebe_*`-themed) | `fragment_password.xml` | 🟡 theme done, structure pending | Low |
| 4 | Missing icons | 45 `ic_/icon` drawables vs EBE's **167**; `ic_sale/void/refund/settle/balance/history/print/logout` all **MISSING** | `business/uikit` + app `res/drawable*` | 🔴 major asset gap | Low (assets) but broad |
| 5 | Settings screens | `activity_itp_settings*.xml`, `activity_qi_card_settings.xml`, `activity_reversal_settings.xml`, … (only **1** settings layout themed) | `activity_settings_main.xml` + `preference_item_setting*.xml` | 🔴 mostly not updated | Low–Med |
| 6 | Transaction list (Merchant) | `activity_transactions_list.xml`, `element_transaction.xml` (both themed) | `fragment_trans_record_list.xml` + `item_trans_record.xml` | 🟡 theme done, structure pending | Low |
| 7 | Settlement screens + icons | `activity_*batch_*.xml` (~6; only `activity_batch_production` themed; MC/Qi variants not) | `fragment_settle.xml` + `item_settle_details.xml` | 🔴 not updated + icons missing | Low–Med |
| 8 | Transaction activity (borders) | `activity_layout_transaction_status_newui.xml` (0 `ebe_` refs, no border/stroke) | `fragment_trans_record.xml` | 🔴 borders/align missing | Low |

## Per-item detail

### 1 — Amount entry (🔴)
`activity_keyboard_transaction.xml` has **no** `ebe_*` references — the reskin did not reach it. EBE shows a single amount field + a styled keypad (`amount_keyboard.xml`). **Port:** restructure the input box + keypad to EBE's `fragment_enter_amount` arrangement and `amount_keyboard` button styling; apply `ebe_*` colours. **Effort:** M.

### 2 — Card reading animations (⛔, HIGH RISK)
No card-animation dialog or Lottie card assets exist in this repo (Lottie is used only for a *fingerprint* animation in `QiTransactionActivity`). EBE drives `{insert,tap,swipe}_card.json` via `LottieFragment`, cycling by enabled entry mode, localized en/ar. **Port:** copy EBE Lottie assets; add a `LottieAnimationView` dialog; show at `ItpEMVCardActivity.onSearchCard()` and dismiss on card-found/error in the `searchCard(...)` callback. **Risk:** non-cancelable dialog over a live EMV transaction — a wrong dismiss path can hang the card-read UI. **Requires on-device verification.** **Effort:** M–L.

### 3 — Settings password (🟡)
`activity_password_dialog.xml` already uses `ebe_background/surface/key_ok` + EBE CardView keypad. Gap = structural match to EBE `fragment_password` (rounded `radius_border` inputs, field arrangement). **Port:** bring in EBE `bg.xml` + `radius_border.xml` drawables; align the field/keypad layout while preserving the existing `ml_keyb_*` and `passwordEditText` IDs the activity binds. **Effort:** S.

### 4 — Missing icons (🔴, broad)
Repo has **45** icon drawables vs EBE's **167**; core action icons (sale/void/refund/settle/balance/history/print/logout) are absent — this is why settlement and merchant screens "look like the old version." **Port:** copy the EBE icon drawable set into each variant's `res/drawable*`, then wire references in the menus/screens that currently show placeholders or old icons. **Effort:** M (sprawl, low risk). Highest visual ROI.

### 5 — Settings screens (🔴)
Many settings layouts; only one is themed. EBE uses a preference-row design (`preference_item_setting*` family) under `activity_settings_main`. **Port:** restyle each `activity_*settings*.xml` to the EBE preference-row pattern + `ebe_*` colours. **Effort:** M–L (many screens × 4 variants).

### 6 — Transaction list / Merchant (🟡)
`activity_transactions_list.xml` + `element_transaction.xml` are already themed; gap = row structure/spacing to match EBE `item_trans_record`. **Port:** align `element_transaction.xml` row layout (icon + amount + status arrangement) to EBE. **Effort:** S–M.

### 7 — Settlement (🔴)
Of ~6 batch layouts, only `activity_batch_production.xml` is themed; the MasterCard/Qi variants are not, and settle icons are missing (depends on item 4). **Port:** apply EBE `fragment_settle`/`item_settle_details` structure + colours across all `*batch*` layouts; wire settle icons. **Effort:** M.

### 8 — Transaction activity (🔴)
`activity_layout_transaction_status_newui.xml` has no `ebe_*` refs and no border/stroke drawables — matches the reviewer's "borders were removed." **Port:** restore EBE row/section borders (stroke drawables) + alignment from `fragment_trans_record`; apply `ebe_*` colours. **Effort:** S.

## Recommended sequence (by impact / low→high risk)
1. **Icons (4)** — broadest visual fix, unblocks 5 & 7, zero flow risk.
2. **Transaction activity borders (8)** — surgical, high visibility.
3. **Amount entry (1)** + **Transaction list rows (6)** — core transaction screens.
4. **Password (3)** + **Settings (5)** + **Settlement (7)** — screen-by-screen restyle.
5. **Card animation (2)** — last; needs on-device verification of the EMV-flow wiring.

## Notes for implementation
- All variants build for **Windows**; on macOS, `mPos.P2.11/app/build.gradle` hardcodes a Windows keystore path (`C:/CQI/.../Q2POS.jks`) that breaks Gradle config — F2/Q2 are cleaner local-build targets.
- Screens are duplicated per variant (F2/P2/P2.11/Q2) — every change applies ×4.
- Working branch: local `ai_dev` based on `origin/bp_dev` (no upstream set).
