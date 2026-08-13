# bnprs.in subdomain standard — review and provisioning plan

**Agent:** na-003/013 bnprs-subdomains · **Date:** 2026-08-13
**Input:** `01-dendrite/inputs/2026-08-13-subdomain-table-source.md` (66 hostnames as proposed)
**Registry now holds 87** across 11 products, hierarchical, all `planned` — amendments in
`01-dendrite/inputs/2026-08-13-amendment-*.md`
**Registry:** `01-dendrite/connectors/subdomain-registry.yaml` ← edit this, not this document

---

## 1. The headline

**0 of the 66 proposed hostnames resolve.** Not one. The table is a plan, and nothing
in it has been provisioned. That is the single most useful fact here, because it means
every structural decision below is still free — including the one I would change.

What *has* been provisioned is five ALB host-header rules on `utms-shared-alb` in
eu-central-1, with no DNS behind any of them:

| host rule on `utms-shared-alb` | in the table? |
|---|---|
| `utms-api-uat.bnprs.in` | yes |
| `bnet-api-uat.bnprs.in` | yes |
| `aandhipe-mpos-api-uat.bnprs.in` | yes |
| `bnet-smartpresence-api-uat.bnprs.in` | **added 2026-08-13** |
| `tms-api-uat.bnprs.in` | **no** |

So the migration has started, ahead of both the DNS and the standard, and it had already
invented two names the standard did not allow. One of those (SmartPresence) has since
been adopted into the table; `tms-api-uat` is still unexplained.

## 2. What the table gets right

The scheme is predictable, greppable, sorts by product, and the
product-component-environment triple is unambiguous once you know it. Every name is
lowercase-safe, hyphen-separated, and well inside the 63-char label limit — under the
hierarchical form finally adopted the longest first label is `bnet-smartpresence-api`
(22 chars), since the environment became a separate label. A developer can derive any hostname without looking it up, which is the
main thing a naming standard is for.

My objections are about the **environment boundary** and the **gaps** — not the shape.

## 3. Findings

### 3.1 Flat naming puts all three environments in one certificate — ACCEPTED, now RESOLVED

> **Decided 2026-08-13: HIERARCHICAL.** The form is
> `<product>[-<subproject>]-<component>.<env>.bnprs.in`, production the bare
> `<product>[-<subproject>]-<component>.bnprs.in`. All 87 host values in the registry were
> rewritten the same day — only the 58 non-prod names changed, since production was always
> bare. The argument below is kept because it is the reasoning behind the decision, but read
> it as settled, not open. Two costs came with it, tracked as `task-015` (the two new certs)
> and `task-016` (rewriting the stale flat ALB rules); both must land before the first
> non-prod record.


The proposed shape makes every hostname a single label under `bnprs.in`. So one
wildcard, `*.bnprs.in`, covers `…-sandbox`, `…-uat` **and** production simultaneously.
That certificate is already ISSUED in account 819144294008.

Consequences:

- **One private key spans every environment.** A compromised sandbox host holds a
  certificate that is valid for production hostnames. There is no cryptographic
  boundary between the environment where people experiment and the one customers use.
- **Per-environment delegation becomes impossible.** You cannot hand `uat.bnprs.in` to
  a UAT account, or apply different WAF/Route53/IAM boundaries per environment, because
  there is no per-environment zone to delegate.
- **It contradicts what this org already does.** Two hierarchical schemes are live
  today: `*.uat.itpgateway.com` with `projects-api.uat.itpgateway.com` on
  `nagents-uat-alb`, and the **delegated** `bruid.bnprs.in` zone with its own
  `*.bruid.bnprs.in` certificate.

**Recommendation — keep the readable prefix, move the environment into its own label:**

```
bnet-api.uat.bnprs.in          bnet-api.sandbox.bnprs.in          bnet-api.bnprs.in
```

Then delegate `uat.bnprs.in` and `sandbox.bnprs.in` as their own zones with their own
wildcard certs, and a non-production key can never sign a production hostname.

**Cost of switching, as finally counted:** four ALB host-header rules to rewrite (a fifth,
`tms-api-uat`, is Terraform-managed), 0 DNS records — and **two new ACM certificates**,
`*.uat.bnprs.in` and `*.sandbox.bnprs.in`, because `*.bnprs.in` matches one label and so
covers only the production column. An earlier draft of this document said "5 ALB rules and
0 DNS records"; that omitted the certificates, which are the real prerequisite.

### 3.2 `nAgent-*` had a capital letter — RESOLVED by renaming to `bna`

`nAgent-api-uat.bnprs.in` was the only mixed-case entry in the table, while `mGate` was
correctly lowercased to `mgate`. DNS lookups and ALB host-header matching are both
case-insensitive, so it would have appeared to work; the damage lands where the literal
string is compared case-*sensitively* — OIDC `redirect_uri` (exact match), CORS origin
checks in most frameworks, certificate SANs, hand-written config.

**Resolved 2026-08-13:** the product is renamed **`nAgent` → `bna`**, which has no
capital and no plural form, so both this and the singular/plural question disappear. It
also aligns the DNS name with `na-010-bna-platform`.

The infrastructure remains named `nagents-*` (`nagents-uat-alb`, `nagents-uat-livekit-nlb`).
DNS and infra names now diverge for this product, which is fine — infra names are
internal — but don't "fix" either to match the other without asking.

### 3.2b Sub-projects get names, not paths — and that makes the standard self-consistent

Settled 2026-08-13, and it applies to **every** product's sub-projects. Paths were
specified first and reversed the same day; nothing had been provisioned in between, so
the reversal cost nothing.

```
<product>-<subproject>-<component>.<env>.bnprs.in
<product>-<subproject>-<component>.bnprs.in          (production)

bna-sprints-portal.uat.bnprs.in       bna-sprints-api.uat.bnprs.in
bna-erp-portal.uat.bnprs.in           bna-erp-api.uat.bnprs.in
bna-chat-portal.uat.bnprs.in          bna-chat-api.uat.bnprs.in
bnet-retail-api.uat.bnprs.in          (api-only sub-project)
```

The sub-project slot sits **between product and component**, so specificity still reads
left to right — and the result is the same shape as the SmartPresence entry already in
the table, `bnet-smartpresence-api.uat.bnprs.in`.

**This is the important consequence: there is now one rule for the whole standard.**
Every addressable thing is `<product>[-<subproject>]-<component>.<env>`. The
`host_vs_path` discriminator has been deleted from the registry — it existed only to
decide which things got hostnames and which got paths, and I had to flag it as *inferred
rather than stated*. Nothing is inferred now.

Two further gains over paths:

1. **No base-path rework, and no app is disqualified.** Each sub-project is served at the
   root of its own host, so base href, router basename and asset paths all stay `/`. The
   blank-page-with-nothing-in-the-log failure mode disappears, and "this third-party app
   cannot be rebased" stops being a blocker.
2. **Real isolation.** A distinct hostname is a distinct browser origin, so cookies,
   `localStorage` and `sessionStorage` do not cross between sub-projects, and an XSS in
   one does not reach the others. Under paths there was no such boundary — a cookie's
   `Path=` is advisory, not an origin.

**The cost, and it is worth planning for:** every sub-project origin must be registered
separately — its own OIDC `redirect_uri`, its own CORS allow-list entry, its own ALB host
rule, its own DNS record. For BNA that is 3 sub-projects × 2 components × 3 environments
= **18 hostnames**, where paths needed 2. The bill is paid in auth configuration, not
DNS. Sub-projects add **no certificate cost of their own** — the sub-project stays inside
the first label, so a sub-project name is covered by the same per-environment wildcard as
its parent product. (Those per-environment wildcards do have to exist: see §3.1 and
`task-015`.)

Migration also gets simpler: the five live `nagents-uat-alb` hosts become a **1:1**
re-shaping rather than a collapse, so each cutover is independent and can be done one at
a time.

### 3.2c Not every product owns every component

Three entries are **api-only, deliberately** — recorded as such so a later pass does not
"restore" the missing portal names as an oversight:

| Entry | Portal |
|---|---|
| `bnet` → smartpresence | none — machine clients only |
| `bnet` → retail | none, by instruction |
| `bruid-rengine` | **served by `bruid-acs-portal.<env>`** |

The rEngine case is a shared portal, and it deliberately re-merges two trust surfaces that
separate hostnames would have kept apart. One origin means one OIDC `redirect_uri` set and
one CORS allow-list — but that allow-list must permit **both** `bruid-acs-api.*` and
`bruid-rengine-api.*`, and a session issued at that portal carries authority over both
services. Scope roles per service, not per origin.

It is also **evidence for `d5`**: rEngine sharing the ACS portal means they are one UI with
two APIs, which matches the infra naming where `wgate-uat-acs` and `wgate-uat-risk-engine`
are both `wgate-*`. Recorded, not acted on — re-parenting rEngine would rename all three of
its API names, which is a decision, not an inference.

### 3.3 Production is the name you get by accident

Production is the bare `<product>-<component>.bnprs.in` — i.e. the value produced when
the environment token is *absent*. Any template of the form `${product}-api-${env}`
with `env` unset, empty, or stripped lands on production.

This estate has been bitten by that exact shape repeatedly — `BNET_COMPANY_ID`,
`BNET_RUNTIME_DIR` and a missing ONNX model each silently resolved to a default and
presented as an unrelated failure. Here the default has the largest possible blast
radius. Keep the bare hostname as the published production name if you like, but forbid
templating environments into hostnames: enumerate the three explicitly in config.

### 3.4 Real services with no name in the table

Each of these exists and serves traffic. Omitting them from the standard does not
retire them — it means they stay on `itpgateway.com` or behind a raw ELB name after the
migration, which is precisely the split-brain that broke bNet.

1. **Keycloak / auth** — `accounts-uat.itpgateway.com`, `accounts.itpgateway.com`,
   `utms-auth.itpgateway.com`. Shared by every product. If products move and auth does
   not, both domains stay alive permanently and every issuer, `redirect_uri` and CORS
   allow-list spans two apexes. **Highest-priority gap.**
2. **SmartPresence API** — ~~no name~~ **resolved 2026-08-13**: adopted into the table as
   `bnet-smartpresence-api-<env>.bnprs.in` across all three environments. Still the gap
   breaking bNet v2 until DNS exists (§4).
3. **bengine / bPassEngine** — live at `bengine.sandbox.bruid.bnprs.in` and
   `uat-bpassengine.bruid.bnprs.in`, ALB `wgate-uat-bengine`. Three names already.
   Probably bRuID Pass's engine — confirm, don't assume.
4. **tms / btms** — `tms-api-uat.bnprs.in` has a rule; `tms.itpgateway.com` and
   `btms-api.itpgateway.com` are live. Distinct product, or the old name for uTMS?
5. **MQTT / WebRTC / streaming** — `utms-emqx-nlb`, `utms-rsi-nlb`,
   `nagents-uat-livekit-nlb`, `tms-emqx`, `tms-webrtc`. These are **NLBs**: there is no
   host-header routing at layer 4, so each needs its own DNS name pointing at its own
   load balancer. The `-api`/`-portal` component vocabulary has no slot for them —
   decide a token (`-mqtt`, `-rtc`, `-stream`).
6. **mini-apps**, and the internal tooling set (`erp`, `projects`, `chat-api`,
   `kc-temp`) — all currently hierarchical under `*.uat.itpgateway.com`.

### 3.5 bRuID: the table and the infrastructure disagree about what a product is

The table lists ACS, wGate, rEngine and Pass as four sibling products. The
infrastructure treats them as components **of wGate** — every load balancer is
`wgate-uat-<thing>`. And the live DNS uses a delegated `bruid.bnprs.in` zone that
already contains **two different orderings**:

```
acs.sandbox.bruid.bnprs.in          <component>.<env>.<product>.bnprs.in
bengine.sandbox.bruid.bnprs.in
risk.sandbox.bruid.bnprs.in
uat-acs.bruid.bnprs.in              <env>-<component>.<product>.bnprs.in
uat-bpassengine.bruid.bnprs.in
```

Adopting the flat table would make this a *third* convention for the same services, and
would abandon a delegated zone and a dedicated certificate that already work. Whatever
is decided, bRuID needs an explicit migrate-or-keep call.

Related: **rEngine is named three ways** — `rengine` (table),
`wgate-uat-risk-engine` (ALB, and it is *internal*), `risk` (live DNS).

### 3.6 Dangling records are an active hazard, not a tidiness issue

`smartpresence-api-uat.itpgateway.com` is a Route53 alias to a load balancer that has
been deleted. It still lists in `list-resource-record-sets`, so it looks healthy in the
API, but the authoritative nameserver answers `NOERROR, ANSWER: 0` and the name resolves
to nothing. That is what broke bNet v2 today.

For ALB aliases the takeover risk is low, since ELB DNS names are not freely
re-claimable in practice; for S3, CloudFront or Elastic Beanstalk targets the same
pattern is a genuine subdomain-takeover vector. Either way the standard needs one rule:
**a record and its target are created and destroyed in the same change**, plus a
standing sweep for records whose targets no longer exist.

### 3.7 Provision on first deploy, not up front

The table implies 66 names including a `-portal` for every product, some of which may
have no portal. Creating names ahead of services produces exactly the two drift states
found today: rules without DNS, and DNS without targets. Reserve the *pattern*
centrally; create the *record* when there is something to point it at.

---

## 4. The live incident this review came out of

**bNet v2 cannot reach its API.** Symptoms: `sync cycle: 0 tables ok, 15 failed`,
`nodename nor servname provided`, and the Identified-people panel showing `failed`.

The API is fine — ECS `utms-smartpresence-api` on `utms-cluster` is ACTIVE 1/1, and its
target group `utms-smartpresence-api-tg:8080` is attached to `utms-shared-alb`. Only the
address is broken.

| option | change | trade-off |
|---|---|---|
| **A — immediate unblock** | Repoint `smartpresence-api-uat.itpgateway.com` at `utms-shared-alb` | Fastest, and needs no certificate work: `*.itpgateway.com` is already the **default** cert on that listener. Keeps a domain you intend to retire alive a while longer. |
| **B — the target state** | Add DNS for `bnet-smartpresence-api.uat.bnprs.in` → `utms-shared-alb`, then point the app at it (the ALB rule still carries the flat name — rewrite it first, `task-016`) | Correct end state, and the ALB rule already exists. Needs the apex zone owner (`decisions.d7`) **and** confirmation that the listener presents a `*.bnprs.in` cert for that SNI name — the default cert on :443 is `*.itpgateway.com`, and a second cert is attached whose identity I did not get to verify. |
| ~~C — fold it in~~ | ~~Serve SmartPresence under `bnet-api-uat.bnprs.in` on a path prefix~~ | **Ruled out 2026-08-13.** The user adopted the dedicated hostname, and `scheme.host_vs_path` agrees: SmartPresence is separately deployed with machine callers, so it earns a host. |

**Recommendation: A now, B as the target.** A restores service today without
prejudging `decisions.d1`; B lands once the scheme is ratified. With `decisions.d3` now
closed in favour of the dedicated host, B's only remaining blockers are the apex zone
owner (`task-001`) and the certificate check (`task-006`).

⚠️ Before B, verify the second SNI certificate on the `utms-shared-alb` :443 and :8443
listeners (`210edefa-cbda-4971-80cd-4a9a4e0280ce`). If it is not `*.bnprs.in`, every
`bnprs.in` host on that ALB will fail TLS the moment DNS is added — the same class of
error as the original mismatch, and the five existing rules are all waiting on it.

---

## 5. Provisioning plan

### Phase 0 — decisions (blocking, no AWS changes)

Nothing below can proceed safely without these. All are tracked in the registry's
`decisions:` block.

| id | decision | blocks | status |
|---|---|---|---|
| d9 | How do bnprs-account records reach ITP-account load balancers? | first record | **OPEN** |
| d8 | Does auth migrate to `bnprs.in`? | auth + every client | OPEN |
| d5 | Is bRuID a family or is wGate the product? `rengine`/`risk-engine`/`risk`? | 9 names | OPEN |
| d4 | Explicit `-prod` token or bare name? | config policy | OPEN |
| d6 | Which agent owns each AandhiPe surface? | 18 names | OPEN |
| d1 | ~~Flat or hierarchical?~~ | — | **RESOLVED** — hierarchical, 87 names rewritten |
| d2 | ~~`nAgent` case, singular vs plural~~ | — | **RESOLVED** — renamed to `bna` |
| d3 | ~~SmartPresence: own host or path?~~ | — | **RESOLVED** — own host, in the table |
| d7 | ~~Who owns the `bnprs.in` apex zone?~~ | — | **RESOLVED** — bnprs acct 891963159778, `Z04234212M3SJ07Y70SGQ` |

**Superseded by the hierarchical decision:** the old ordering had `d7` and `d1` as the top
blockers. Both are closed. The critical path is now `d9` (record form) → `task-015` (certs)
→ `task-016` (rule rewrites) → `task-007` (first records).

### Phase 1 — restore bNet UAT

Option A from §4. One Route53 change, reversible, no certificate work.

### Phase 2 — certificate and listener preparation

1. ~~Verify cert `210edefa-…`~~ **done** — it is `*.bnprs.in`, ISSUED, expires 2027-02-26,
   attached as the non-default SNI cert on both `:443` and `:8443`.
2. **Request `*.uat.bnprs.in` and `*.sandbox.bnprs.in`** (`task-015`) — now mandatory, not
   conditional. `*.bnprs.in` matches one label, so it covers the production column and
   nothing else. Issue them in the ITP account where TLS terminates; the DNS validation
   records go in the bnprs-account zone, so this spans both accounts.
3. Attach both to the listener **before** any non-prod DNS record exists.
4. Decide the per-env zone delegations (`task-017`) — the payoff hierarchical unlocks.

### Phase 2b — rewrite the stale ALB rules (`task-016`)

Four live host-header conditions (`utms-api-uat`, `bnet-api-uat`,
`bnet-smartpresence-api-uat`, `aandhipe-mpos-api-uat` `.bnprs.in`) were created before the
scheme was ratified and now match nothing in the registry. Rewrite them to the hierarchical
names **while no DNS points at them** — the change is free today and becomes a live cutover
the moment a record exists. `tms-api-uat` is Terraform-managed; change it there, and only
once `tms` has an agreed name at all.

### Phase 3 — UAT records for what already exists

The four names above, once `d9` fixes the record form (CNAME vs cross-account ALIAS) and
phases 2 and 2b are complete. Each one: create record → `dig` → `dig @authoritative-ns` →
HTTPS probe **confirming the served cert subject matches the name asked for** → target
health → flip registry status to `live` with the date. No batch changes; one name at a time.

### Phase 4 — sandbox and production

On first real deploy of each service, never in advance (§3.7).

### Phase 5 — decommission

Retire the `itpgateway.com` product hostnames only after their `bnprs.in` equivalents
are `live` and clients are cut over. Delete each record **in the same change** as its
target. Mark `retired` in the registry — never silently reuse a name.

### Phase 6 — standing hygiene

- Sweep for records whose targets no longer exist (the §3.6 check)
- Sweep for ALB host rules with no DNS record (today: five)
- Re-verify `live` statuses periodically; `live` is a claim with an expiry date

---

## 6. Handoffs

- **na-009/008 bpr1008-bnet** — currently broken; its `App.config`, `BNET_API_BASE` and
  `run-macos.sh` host guard all still name `smartpresence-api-uat.itpgateway.com`. That
  guard rejects raw ELB names but happily accepted a hostname that resolves to nothing;
  widen it to a reachability check.
- **na-003/002 bnprs-aws-itp** — owns account 819144294008; needed for ACM, ALB and
  Route53 changes, and for finding the account that holds the `bnprs.in` apex.
- **na-003/005 bnprs-websites** — registrar and domain-level ownership context.
- **na-009/007 bpr1007-wgate** — needs to answer `decisions.d5`.
