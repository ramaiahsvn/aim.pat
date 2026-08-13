# Input — amendment: BNA rename and sub-project paths

**From:** user · **Date:** 2026-08-13 · **Amends:** `2026-08-13-subdomain-table-source.md`

> ⚠️ **Section 1 of this file is SUPERSEDED** by
> `2026-08-13-amendment-2-subprojects-are-names.md`, later the same day: sub-projects use
> **name notation, not paths**. Sections 2 (bna rename) and 3 (SmartPresence) still stand.
> Kept unedited because it is a record of what was asked, not of what was decided.

Three instructions, given after reviewing the table. Reproduced as received.

## 1. Sub-projects are paths, not subdomains  ← SUPERSEDED, see amendment 2

> "in nAgent, we have sub-projects: Sprints, ERP, and Chat. but its portal paths should be
> like like nAgent-portal.bnprs.in/sprints; nAgent-portal.bnprs.in/erp;
> nAgent-portal.bnprs.in/chat. **this notation for all subprojects**"

So the convention is general — every product's sub-projects take a path on the product's
host, not a hostname of their own:

```
<product>-<component>[-<env>].bnprs.in/<subproject>
```

## 2. nAgent is renamed to bna

> "the existing nAgent in above table can be renamed as bna"

Applied to the whole row. With the examples above rewritten under the new name:

```
bna-portal.bnprs.in/sprints        bna-portal-uat.bnprs.in/sprints
bna-portal.bnprs.in/erp            bna-portal-uat.bnprs.in/erp
bna-portal.bnprs.in/chat           bna-portal-uat.bnprs.in/chat
```

This also closes `decisions.d2` — the capital-A and singular/plural questions only
existed because the name was `nAgent`.

## 3. SmartPresence gets its own host

> "bnet-smartpresence-api-uat.bnprs.in, yes include in table."

Closes `decisions.d3` in favour of a distinct hostname rather than a path under
`bnet-api`. Now a full member of the table across all three environments.

---

## Consequences recorded in the registry

- `scheme.subproject_form` — the path notation, with its rules
- `scheme.host_vs_path` — the discriminator these two decisions imply: a separately
  deployed service with non-portal callers gets a host; a surface reached through the same
  portal and login gets a path. **Inferred from the two decisions, not stated** — flagged
  as such in the registry.
- `products.bna` — renamed, with `subprojects:` for sprints / erp / chat
- `products.bnet.components.smartpresence-api` — added, 3 environments
- `unmapped_endpoints` — the six live ERP/projects/chat subdomains are now `mapped`

## Two things to confirm before migrating

1. **`projects` → `sprints` is an assumption.** The live hosts are
   `projects.uat.itpgateway.com` and `projects-api.uat.itpgateway.com`; the instruction
   says *Sprints*. Treated as the same thing. If they are not, one of them has no name.
2. **Each app must be base-path aware before its subdomain is retired.** A portal moved
   to `/sprints` that still resolves assets from `/` renders an empty page with nothing
   useful in the log, and some third-party apps cannot be rebased at all.
