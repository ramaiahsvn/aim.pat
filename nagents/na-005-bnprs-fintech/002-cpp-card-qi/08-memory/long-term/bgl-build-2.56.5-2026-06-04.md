---
name: bgl-build-2.56.5
description: BprCardQi v2.56.5 windows-64 built with BGL file-load exports + lazy gate + kid=3; bgl-enroll.exe built
metadata:
  node_type: memory
  type: project
---

**Built BprCardQi 2.56.5 (windows-64) on 2026-06-04** for the BGL fleet-licensing line (na-003/011).

- Bumped 2.56.4→2.56.5 in `bpr_versions.h`, `bpr_versions.cmake`, `Makefile` (commit `d40140c`).
- `make BprCardQi-windows-64` → `build/bnprs-libs/BprCardQi/v2.56.5/windows-64/libBprCardQi.dll`.
  Export table confirmed: `bpr_cardqi_activate / _is_licensed / _hwid / _activate_from_store /
  _license_path`. Embeds **kid=3** pubkey; chokepoint `BprPcSc_Context_Init` lazy-loads
  `C:\ProgramData\BprCardQi\<hwid>.lic`.
- Built `bgl-enroll.exe` via `cli/BprCardQi/enroll/CMakeLists.txt` →
  `build/bnprs-libs/bgl-enroll/windows-64/bgl-enroll.exe`.
- Test folder assembled (DLL renamed `BprCardQi.dll` + exe) at `bpr.cpp/build/win-test/` for the
  owner's real-Windows test. **How to apply:** for the canonical fleet release, also build
  windows-32 / android-arm64 as needed; real-Windows hwid (`MachineGuid`+C: volserial) test still pending.
