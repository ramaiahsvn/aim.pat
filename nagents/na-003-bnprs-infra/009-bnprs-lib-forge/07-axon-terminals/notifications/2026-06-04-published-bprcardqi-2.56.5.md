# PUBLISHED — BprCardQi 2.56.5 (bnprs-lib-forge na-003/009)

**Date:** 2026-06-04 · GitLab project 230 (BPR1000/bpr1000.bnprs-libs), generic registry.

- **package_id 19**, version 2.56.5. Files: `windows-64/libBprCardQi.dll` (+ `.sha256`), `manifest.json`.
- sha256 `5373c89cb6a583433d334edc22b32dde9c4230d9ebc20ed0b1513f89ea547392`; source bpr.cpp @ 6108979.
- libraries.yaml updated (latest BprCardQi → 2.56.5 + published entry). Requested by na-003/011.
- Only windows-64 for this version; other platforms on request to na-005/002 cpp-card-qi.

Consume (deploy token bnprs-libs-readonly):
  curl --fail --header "DEPLOY-TOKEN: $BNPRS_LIBS_DEPLOY_TOKEN" -o libBprCardQi.dll \
    "https://gitlab.bnprs.ai/api/v4/projects/230/packages/generic/BprCardQi/2.56.5/windows-64/libBprCardQi.dll"
