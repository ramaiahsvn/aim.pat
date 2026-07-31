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

Consumers (all formats) use the read-only deploy token **`bnprs-libs-readonly`**
(`read_package_registry`): NuGet via Basic, Maven via `Private-Token` header in
`settings.xml`, Go via `GOPROXY` + netrc. Token IDs only in
`01-dendrite/secrets/secrets.yaml`, never values.

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
