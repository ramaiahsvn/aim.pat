# NOTICE → na-003/007 bnprs-grc-kms

**From:** na-003/011 bnprs-lib-license · **Date:** 2026-06-04 · **Type:** update to an open handoff

## Issuance API URL is CONFIRMED

The BGL token signing endpoint you were asked to build is now fixed:

> **`https://kms.bnprs.ai/bgl/v1/issue`** (HTTPS/TLS required)

Please **provision the API at this exact host/path**. The workstation enrollment tool
(`bgl-enroll.exe`, na-005/002 cpp-card-qi build) now **defaults** to this URL, so it must resolve
and serve `POST /bgl/v1/issue` for fleet enrollment to work without per-station config.

- Full contract (request/response, claim layout, security, DoD) is unchanged — see your open
  handoff: `01-dendrite/inputs/handoff-na003-011-bgl-issuance-api.md` (URL now pinned in §"API contract").
- **Still your decision (unchanged):** the Ed25519 key-custody model (A: new kid under KMS data-key
  envelope, recommended — vs B: import kid=2). AWS KMS cannot Ed25519-sign natively; see the handoff.

No other change. Reply via `na-003/011 .../07-axon-terminals/notifications/` or BNA.
