# Input — amendment 2: sub-projects use name notation, not paths

**From:** user · **Date:** 2026-08-13
**Supersedes:** section 1 of `2026-08-13-amendment-bna-and-subproject-paths.md`

> "for subprojects also name notation, not path"

Reverses the path decision taken earlier the same day. Sub-projects are addressed by
**hostname**, like everything else in the standard:

```
<product>-<subproject>-<component>-<env>.bnprs.in
<product>-<subproject>-<component>.bnprs.in          (production)
```

```
bna-sprints-portal-uat.bnprs.in        bna-sprints-api-uat.bnprs.in
bna-erp-portal-uat.bnprs.in            bna-erp-api-uat.bnprs.in
bna-chat-portal-uat.bnprs.in           bna-chat-api-uat.bnprs.in
```

The sub-project slot sits **between product and component**, so specificity keeps reading
left to right, and the name is identical in shape to the SmartPresence entry already in
the table: `bnet-smartpresence-api-uat.bnprs.in`.

## Why this is the better outcome, not just a different one

**There is now one rule for the entire standard.** Every addressable thing is
`<product>[-<subproject>]-<component>[-<env>]`. The `host_vs_path` discriminator has been
deleted from the registry — it existed only to decide which things got hostnames and which
got paths, and I had to flag it as *inferred rather than stated*. Nothing is inferred now.

**No base-path rework, and no app is disqualified.** Each sub-project is served at the root
of its own host, so base href, router basename and asset paths all stay `/`. The
blank-page-with-no-useful-error failure mode is gone, and "this third-party app cannot be
rebased" stops being a blocker.

**Real isolation.** A distinct hostname is a distinct browser origin, so cookies,
`localStorage` and `sessionStorage` do not cross between sub-projects, and an XSS in one
does not reach the others. Paths gave no such boundary — `Path=` on a cookie is advisory.

## What it costs

**Every sub-project origin must be registered separately** — its own OIDC `redirect_uri`,
its own CORS allow-list entry, its own ALB host rule and its own DNS record. For BNA that
is 3 sub-projects × 2 components × 3 environments = **18 hostnames**, where paths needed 2.
The bill is paid in auth configuration, not DNS.

No new certificate is needed: sub-projects are single labels under the apex, so the
existing `*.bnprs.in` wildcard already covers them under the flat scheme. (If `decisions.d1`
goes hierarchical, they stay single labels under each environment zone — still covered.)

Label length stays safe — the longest name in the registry is now 30 characters against a
63-character limit — but four segments leaves less headroom, so watch it as sub-projects
are added to products with longer names.
