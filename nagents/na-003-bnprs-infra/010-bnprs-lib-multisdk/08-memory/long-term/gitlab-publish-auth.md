---
name: gitlab-publish-auth
description: Per-format publish auth + endpoints for GitLab project 230 (verified in BprFace pilot 2026-06-01)
metadata:
  node_type: memory
  type: reference
---

GitLab CE 18.9, host project **230** (`BPR1000/bpr1000.bnprs-libs`). Publish auth **differs
per package format** — verified end-to-end in the BprFace 2.24.114 pilot:

| Format | Endpoint | Publish auth | Note |
|--------|----------|--------------|------|
| Generic | `…/projects/230/packages/generic/<pkg>/<ver>/<file>` | `PRIVATE-TOKEN: $GITLAB_PAT` header | lib-forge's existing path |
| **NuGet** | `…/projects/230/packages/nuget/` — **PUT, trailing slash REQUIRED** | **HTTP Basic ONLY** — `curl --request PUT --user <user>:$GITLAB_PAT --form package=@…` (user=`root` here) | `PRIVATE-TOKEN` header → **401**; Basic → 201 |
| **Maven** | `…/projects/230/packages/maven/<group-path>/<artifact>/<ver>/<file>` | `Private-Token: $GITLAB_PAT` header (PUT jar + pom) | HTTP 200 |
| **Go** | `…/projects/230/packages/go` (proxy) | **no upload endpoint** | tag-based: serves SemVer **git tags** from a repo via the Go proxy; publish = commit module + tag |

Consumers use the read-only deploy token **`bnprs-libs-readonly`** (username `bnprs-libs-ro`,
`read_package_registry`) — defined on the **GROUP `BPR1000` (id 118), NOT on project 230**; group
scope covers the project. `GET /projects/230/deploy_tokens` returns empty, which looks like the
token is missing. Check `/groups/118/deploy_tokens`. Token IDs only in
`01-dendrite/secrets/secrets.yaml`, never values.

**A DEPLOY token is not a `Private-Token`** (corrected 2026-07-31, after a consumer hit it):

| token type | header |
|---|---|
| personal access token (`read_api`) | `Private-Token` |
| deploy token (`read_package_registry`) | `Deploy-Token` — the token VALUE, not the username |

Using `Private-Token` with a deploy token 401s exactly like no credentials at all. And **every
client reports a 401 as "not found"** — Maven marks the artifact `(absent)`, IntelliJ prints
"Dependency … not found", NuGet says the package does not exist. Diagnose auth first; a bare
`curl` against the .pom distinguishes 401 from a genuine 404 in one call. Deploy-token values
cannot be read back through the API, so a lost one is re-minted, not recovered.

Maven also caches the failure: after fixing credentials,
`rm -rf ~/.m2/repository/<group-path>/<artifact>` and `mvn -U`, or the stale error persists.

**Group deploy tokens issued** (values NOT stored here — GitLab shows them once, and this file is
tracked). All `read_package_registry` only, on group 118:

| id | name / username | for | expires |
|----|-----------------|-----|---------|
| 1 | `bnprs-libs-readonly` / `bnprs-libs-ro` | general consumers | none |
| 3 | `bnprs-libs-ro-charan` | Charan | none |
| 4 | `bnprs-libs-ro-harani` | Harani (uTMS smartpresence) | **2027-07-31** |

Token 4 is the first with an **expiry** — builds depending on it break on that date with a 401
that will look exactly like a misconfiguration. Verified on issue: `Deploy-Token` header and
Basic `username:token` both 200; it cannot read the git repo (401), so package scope is genuinely
enforced. Re-mint per person rather than sharing one token — revoking one then does not break
everyone.

**NuGet has TWO traps, not one** (second one found publishing BprIDEngine 2.24.900, 2026-07-31).
The service index advertises `PackagePublish/2.0.0` at `…/packages/nuget` with **no** trailing
slash, and that URL is a lie for uploads: `POST` there → **404**, `PUT` there → **400 "package is
invalid"**. Only `PUT …/packages/nuget/` **with** the slash returns 201. So don't derive the push
URL from `index.json` — hardcode the trailing slash. Verify with the same PAT on a working leg
(Maven) first, so a 404 is read as a routing bug and not as an auth failure.

**Why:** the NuGet 401-on-header trap cost a debug cycle in the pilot, and the slash/verb trap
cost another. **How to apply:** for each leg use the matching auth above; for Go, plan a tagged
module repo rather than an upload.
Full results: `07-axon-terminals/deliverables/pilot-reports/BprFace-*.md`. lib-forge's
published index mirrors this in `libraries.yaml`.
