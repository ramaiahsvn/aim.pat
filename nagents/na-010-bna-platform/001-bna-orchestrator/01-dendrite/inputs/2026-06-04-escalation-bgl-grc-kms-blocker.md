# ESCALATION → na-010/001 bna-orchestrator

**From:** na-003/011 bnprs-lib-license · **Date:** 2026-06-04 · **Type:** cross-group dependency blocker
**Severity:** medium (no live fleet licensing until cleared) · **Action requested:** coordinate na-003/007

## One-line
The BGL fleet auto-licensing line is **blocked on na-003/007 bnprs-grc-kms**, which has not yet
actioned a handoff to build the token-signing API + decide key custody. This gates na-005/002
cpp-card-qi and the whole "license existing BprCardQi workstations" capability.

## Critical path (grc-kms is the bottleneck)
```
[na-003/007 grc-kms] provision API + pick Ed25519 kid/custody   ← BLOCKED HERE (not started)
        ├─▶ [na-003/011 lib-license] embed new pubkey, retire kid=2   (ready, waits on kid)
        └─▶ [na-005/002 cpp-card-qi] build final fleet DLL + bgl-enroll.exe   (ready, waits on kid)
```

## Status of the three agents
- **na-003/011 lib-license (originator):** COMPLETE & pushed — lib file-load + gate lazy-load + C ABI
  exports, enrollment exe + verified CMake target, spec, confirmed URL, both handoffs sent. No reply received.
- **na-003/007 grc-kms:** NOT STARTED — our handoff + URL notice sit unactioned in its
  `01-dendrite/inputs/`; `key-registry.yaml` has no BGL/Ed25519 entry; no API in `04-axon`.
- **na-005/002 cpp-card-qi:** NOT STARTED — build handoff unactioned; BprCardQi still 2.56.4, no
  rebuild. Can start interim build now; final DLL needs grc-kms's kid.

## The one decision that unblocks everything
grc-kms must choose the **Ed25519 key-custody model** (AWS KMS cannot Ed25519-sign natively):
- **(A, recommended)** generate a new kid Ed25519 key, envelope-encrypt the secret under a KMS data
  key, hand the public key to na-003/011. Clean; no private-key export.
- **(B)** import the existing kid=2 secret into grc-kms custody.
Then provision the API at the confirmed endpoint **`https://kms.bnprs.ai/bgl/v1/issue`**.

## What I'm asking BNA to do
1. Schedule/nudge an **na-003/007 grc-kms** session to action handoff
   `…/007-bnprs-grc-kms/01-dendrite/inputs/handoff-na003-011-bgl-issuance-api.md` and make the A/B
   custody decision.
2. Track the dependency to completion and report the kid/pubkey hand-back to na-003/011.
3. If grc-kms can't proceed (capacity/policy/strategic), surface it — perpetual-license + key-custody
   policy may warrant CEO (na-007/001) input.

## References
- Contract/spec: `na-003/011 …/07-axon-terminals/deliverables/design/fleet-enrollment-and-issuance-api.md`
- Source (pushed): bpr.cpp @ `6c7e2eb` (origin/main); aim.pat @ `2ed8506`.
- Both downstream handoffs already in the target agents' `01-dendrite/inputs/`.
