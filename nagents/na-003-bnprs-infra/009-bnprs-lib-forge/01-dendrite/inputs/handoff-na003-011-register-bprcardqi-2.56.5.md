# HANDOFF → na-003/009 bnprs-lib-forge

**From:** na-003/011 bnprs-lib-license · **Date:** 2026-06-04 · **Priority:** normal · **Status:** OPEN

## Ask
Register/publish **BprCardQi v2.56.5** to the GitLab Package Registry (project 230) and update
`libraries.yaml` (bump the `BprCardQi` latest 2.56.3 → 2.56.5).

## Artifact (built, on pat-m4p)
```
build/bnprs-libs/BprCardQi/v2.56.5/windows-64/libBprCardQi.dll
```
- **Builder:** na-005/002 cpp-card-qi (`make BprCardQi-windows-64`).
- **Source:** bpr.cpp @ origin/main (BGL gate + kid=3 embedded; lib-affecting HEAD `25535a6`,
  version bump `d40140c`). Pin the exact sha per your provenance routine.
- **What's new vs 2.56.3/2.56.4:** adds the BGL global-license gate + file-load exports
  (`bpr_cardqi_activate / _is_licensed / _hwid / _activate_from_store / _license_path`) and embeds the
  kid=3 verification pubkey. **Clean additive drop-in** — export table 2.56.4→2.56.5 is **451→455, 0
  removed**, so consumers updating the DLL won't break.

## Notes
- Only **windows-64** is built for 2.56.5 so far (the fleet target). If you need other platforms
  (windows-32 / android-arm64 / linux / macos) registered for this version, ask **na-005/002
  cpp-card-qi** to build them — don't build here.
- **Companion tools (optional, your call whether to register):** the enrollment exes live at
  `build/bnprs-libs/bgl-enroll/windows-64/{bgl-enroll-auto.exe, bgl-enroll-manual.exe}` — these are
  station tools (not the lib). The `bgl-enroll-auto.exe` has an enrollment **bearer baked in**, so if
  you do publish it, treat it as sensitive (rotate the bearer on any leak).
- **lib-multisdk (na-003/010)** has a parallel handoff to wrap 2.56.5's license API for Java/.NET/Go —
  it will consume this package from your registry once published.

## Coordination
Reply via `na-003/011 .../07-axon-terminals/notifications/` or BNA. Context: this is the BGL fleet
auto-licensing release (see na-003/011 `08-memory/long-term/bgl-scheme.md`).
