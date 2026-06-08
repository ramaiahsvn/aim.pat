# EBE UI Parity — Implementation Spec (developer-executable)

**Target repo:** `bpr1003.itp.mpos.2.ebe` · **base:** `origin/bp_dev` @ `d295b6b0`
**Reference (read-only):** `bpr1003.mpos.ebe` (UI in `business/uikit/src/ui/`)
**Variants (apply each change ×4):** `mPos.F2`, `mPos.P2`, `mPos.P2.11`, `mPos.Q2` — paths below use `<V>` = variant.
**Shared module:** `mPos.Controller` — already holds the EBE drawables/colours (`ebe_bg_input_field`, `ebe_keyboard_ok_button`, `round_green_btn`, `@color/ebe_*`, …). Reuse these; don't redefine.

> ⚠️ **Build/verify on the Windows host.** This repo does not build on macOS: `:mPos.Controller:debugCompileClasspath` can't resolve vendor AARs `mPosCore_1.10.117` and `sonic-sdk-release-1.5.0`. Every change below must be compiled + visually checked against the rendered EBE screen on the Windows build host before merge.
> Branch: work on `ai_dev` (off `bp_dev`).

---

## Convention: "EBE-ify a screen"
A screen is EBE-styled when it (a) uses `@color/ebe_*` instead of legacy scheme colours, (b) uses the EBE input/keypad/card drawables from `mPos.Controller`, (c) matches the EBE reference layout's structure. Legacy→EBE colour map (verify exact names in `mPos.Controller/res/values/colors.xml`):
| Legacy | EBE replacement |
|--------|-----------------|
| `@color/Dark_blue`, `@color/colorPrimary` (toolbar) | `?attr/colorPrimary` / `@color/ebe_primary` |
| `@color/colorBackground`, `@color/white` (page bg) | `@color/ebe_background` |
| `@color/itp_dollargreeen` (buttons) | `@color/ebe_key_ok` (+ text `@color/ebe_key_ok_text`) |
| `@color/mc_yellow/mc_oranage/mc_red` (status blocks) | `@color/ebe_surface` + `@color/ebe_text_primary` |
| card/input borders | `@drawable/radius_border` or MaterialCardView `app:strokeColor="@color/ebe_divider"` |

---

## Item 1 — Amount Entry  🔴 (risk: Low)
**Target:** `<V>/app/src/main/res/layout/activity_keyboard_transaction.xml` (currently **0** `ebe_` refs; uses `Dark_blue`, `colorPrimary`, `colorBackground`, `itp_dollargreeen`).
**EBE ref:** `fragment_enter_amount.xml` + `amount_keyboard.xml`.
**Steps:**
1. Page root bg → `@color/ebe_background`; toolbar → EBE primary (match `activity_password_dialog.xml`, which is already correct).
2. Amount input: match EBE's `actual_amount_input_field_box` — give the amount `EditText` the EBE input look (`@drawable/ebe_bg_input_field` from Controller, EBE text size/colour, currency prefix per EBE). If `com.pax.commonui.keyboard.CustomKeyboardEditText` is available in this build, prefer it; otherwise style the existing `EditText`.
3. Option buttons (`button_use_pin`, `button_balance_on_screen`, `button_use_fingerprint`, `button_balance_on_receipt`): `backgroundTint` `@color/itp_dollargreeen` → `@color/ebe_key_ok`; text → `@color/ebe_key_ok_text`; use `@drawable/ebe_keyboard_ok_button` shape if EBE uses rounded keys.
4. Keep all existing `android:id`s (activity code binds them).
**Verify:** amount box + keypad visually match EBE enter-amount screen.

## Item 2 — Card Reading Animations  ⛔ (risk: HIGH — EMV flow, device test required)
**Targets:** new `dialog_card_animation_layout.xml` per variant; `<V>/app/.../emv_qi/ItpEMVCardActivity.java`.
**EBE ref:** `business/uikit/src/ui/java/com/pax/uikit/carddetect/searchcard/LottieFragment.java`; assets `business/uikit/src/ui/assets/drawable/default/{en,ar}/{insert,tap,swipe}_card.json` (+ their image folders).
**Steps:**
1. Copy EBE `assets/drawable/default/{en,ar}/` (the 3 JSONs + image folders) → `<V>/app/src/main/assets/drawable/default/`. (Lottie dep already present.)
2. Create `dialog_card_animation_layout.xml` with a `com.airbnb.lottie.LottieAnimationView` (id `cardLottieView`).
3. In `ItpEMVCardActivity`: show the dialog in `onSearchCard()` before `iemv.searchCard(...)`; play localized insert→tap→swipe by setting `setImageAssetsFolder(base+"/")` + `setAnimation(base+".json")` and advancing on `onAnimationEnd` (mirror `LottieFragment.updateAnimJson`). Choose `en/`/`ar/` by `Locale.getDefault().getLanguage()`.
4. **Dismiss on every exit path** of the search callback (card found, `onError`, timeout, activity finish) — a missed dismiss hangs the UI. Audit the `callback`/`checkCardCallback` success+error methods.
**Verify:** on-device card insert/tap/swipe; confirm dialog dismisses on success, error, and timeout.

## Item 3 — Settings Password  🟡 theme done, structure pending (risk: Low)
**Target:** `<V>/app/src/main/res/layout/activity_password_dialog.xml` (already `ebe_*`-themed) + `EnterPasswordActivity.java` (binds `ml_keyb_0..9`, `ml_keyb_ok`, `ml_keyb_rub`, `passwordEditText`).
**EBE ref:** `fragment_password.xml` (rounded `radius_border` inputs, keypad below).
**Steps:**
1. Wrap the `passwordEditText` (or its container) with EBE input styling: `android:background="@drawable/ebe_bg_input_field"` (or `@drawable/radius_border`), EBE padding/corner radius.
2. Align field + keypad spacing/arrangement to `fragment_password` (keep the existing `ml_keyb_*` IDs and CardView keypad — it's already EBE-coloured).
3. Add the password show/hide affordance EBE uses (`avd_show_password`/`avd_hide_password` animated-vectors) if in scope — these are referenced but **not in Controller/EBE**; source from EBE app module or create. *(Flagged: asset not located.)*
**Verify:** input has rounded EBE border; layout matches EBE password screen.

## Item 4 — Missing Icons  🔴 visual/wiring (risk: Low, broad)
**Finding:** there are **no unresolved** `@drawable` references — all resolve via the app module or `mPos.Controller`. "Missing icons" = screens still show **legacy** icons or **omit** EBE icons, not absent files.
**Steps (needs rendered EBE screens to map each icon):**
1. For each EBE screen (sale/void/refund/settle/balance/history/print/logout menus, settings rows, settlement), note the EBE icon used.
2. In the matching this-repo screen, replace the legacy `@drawable/...` with the EBE icon name (the EBE icon set — 167 drawables — lives in `bpr1003.mpos.ebe`; copy any not already in `mPos.Controller` into Controller's `res/drawable` so all variants share them).
3. Specifically wire: menu/grid item icons in `activity_merchant.xml`, settings rows (item 5), settlement screens (item 7).
**Verify:** each screen's icons match EBE; no legacy icons remain.

## Item 5 — Settings Screens  🔴 (risk: Low–Med)
**Targets:** `<V>/.../layout/activity_itp_settings*.xml`, `activity_qi_card_settings.xml`, `activity_reversal_settings.xml`, `activity_mtms_settings_edit.xml`, `setting_item.xml` (only 1 themed today).
**EBE ref:** `activity_settings_main.xml` + `preference_item_setting*.xml` family (preference-row design: icon + title + summary + chevron/switch).
**Steps:** restyle each settings list to the EBE preference-row pattern; convert `setting_item.xml` row to mirror `preference_item_setting.xml`; apply `@color/ebe_*`; wire EBE row icons (item 4).
**Verify:** settings list rows match EBE preference rows.

## Item 6 — Transaction List (Merchant)  🟡 theme done, structure pending (risk: Low–Med)
**Target:** `<V>/.../layout/element_transaction.xml` (already `ebe_surface`/`ebe_divider`/`ebe_text_primary`; currently a simple `right_image`+`left_text` row) + its RecyclerView adapter.
**EBE ref:** `item_trans_record.xml` — richer row: `@drawable/bg_history_item` bg, fields `history_detail_state`, `history_detail_card_no`, amount, expandable section.
**Steps:**
1. Restructure `element_transaction.xml` to EBE's multi-field row (state + masked card no + amount), background `@drawable/bg_history_item` (copy from EBE if not in Controller).
2. **Update the adapter** that binds `element_transaction` to populate the new fields (state/card/amount) — this is a code change, not layout-only.
**Verify:** merchant transaction rows match EBE history rows; adapter binds all fields.

## Item 7 — Settlement Screens  🔴 not updated + icons (risk: Low–Med)
**Targets:** `<V>/.../layout/activity_*batch_*.xml` (~6: `activity_batch_production` [themed], `activity_qi_batch_*`, `activity_mastercard_batch_*`, `activity_qimc_batch_*` [not themed]) + `BatchActivity{,All,Mc,Qi,QiMc_Both,Visa}.java`.
**EBE ref:** `fragment_settle.xml` + `item_settle_details.xml`.
**Steps:** apply the already-done `activity_batch_production` EBE treatment to the MC/Qi/Visa batch layouts (colours + `item_settle_details` row structure); wire settle icons (item 4). Keep scheme-specific fields.
**Verify:** all settlement screens match EBE settle screen; icons present.

## Item 8 — Transaction Activity (borders)  🔴 (risk: Low)
**Target:** `<V>/.../layout/activity_layout_transaction_status_newui.xml` (0 `ebe_` refs; uses `Dark_blue`, `mc_yellow`, `mc_oranage`, `mc_red`, `mtrl_scrim_color`; back-arrow icon is **commented out** at the `imageViewArrowBackButton`).
**EBE ref:** `fragment_trans_record.xml` (row/section borders).
**Steps:**
1. Replace legacy colours per the map above; status blocks (`enterCode`/`title`/`message`) → `@color/ebe_surface` + `@color/ebe_text_primary`.
2. **Restore borders** the reviewer flagged: wrap status rows/sections in `@drawable/radius_border` (or MaterialCardView `app:strokeColor="@color/ebe_divider" app:strokeWidth="1dp"`, matching `element_transaction.xml`).
3. Uncomment + wire the back arrow `app:srcCompat="@drawable/ic__781857_arrow_arrows_back_direction_left_icon"` (source the icon — referenced but not in Controller/EBE; *flagged*).
**Verify:** borders/alignment match EBE; back arrow shows.

---

## Cross-cutting flags (assets referenced but NOT found in Controller or EBE)
Source or create these before wiring: `avd_show_password`, `avd_hide_password`, `ic__781857_arrow_arrows_back_direction_left_icon`, `round_grey_border`, `scan_box_border`, `laser_gradient`, `ic_visa_logo` (Q2). (Some may exist in app-module `res` of a specific variant — check there first.)

## Suggested execution order
Icons (4) → Tx-activity borders (8) → Amount entry (1) + Tx list (6) → Password (3) + Settings (5) + Settlement (7) → Card animation (2, device-verified last).
