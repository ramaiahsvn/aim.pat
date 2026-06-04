# OUTGOING HANDOFFS → lib-forge (na-003/009) & lib-multisdk (na-003/010)

**Date:** 2026-06-04 · **Status:** SENT

After the BprCardQi 2.56.5 BGL release + live API:

1. **→ na-003/009 lib-forge:** register/publish **BprCardQi 2.56.5** (windows-64 in
   `build/bnprs-libs/...`), bump libraries.yaml latest 2.56.3→2.56.5. Clean additive drop-in
   (exports 451→455, 0 removed). →
   `009-bnprs-lib-forge/01-dendrite/inputs/handoff-na003-011-register-bprcardqi-2.56.5.md`

2. **→ na-003/010 lib-multisdk:** proceed next step — wrap the BGL license/activation API
   (`bpr_cardqi_activate/_is_licensed/_hwid/_activate_from_store/_license_path` + BprLicBase
   `BprBgl`/`bpr_bgl_*`) into Maven/NuGet/Go, version 2.56.5; consume the native binary from lib-forge
   or local tree; request other platforms from cpp-card-qi if needed. →
   `010-bnprs-lib-multisdk/01-dendrite/inputs/handoff-na003-011-wrap-bgl-license-api.md`
