# bnprs.in subdomain standard — review and provisioning plan

**Agent:** na-003/013 bnprs-subdomains · **Date:** 2026-08-13
**Input:** `01-dendrite/inputs/2026-08-13-subdomain-table-source.md` (66 hostnames)
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
| `bnet-smartpresence-api-uat.bnprs.in` | **no** |
| `tms-api-uat.bnprs.in` | **no** |

So the migration has started, ahead of both the DNS and the standard, and it has
already invented two names the standard does not allow.

## 2. What the table gets right

The scheme is predictable, greppable, sorts by product, and the
product-component-environment triple is unambiguous once you know it. Every name is
lowercase-safe, hyphen-separated, and the longest
(`aandhipe-mobile-portal-sandbox.bnprs.in`, 39 chars) is comfortably inside the 63-char
label limit. A developer can derive any hostname without looking it up, which is the
main thing a naming standard is for.

My objections are about the **environment boundary** and the **gaps** — not the shape.

## 3. Findings

### 3.1 Flat naming puts all three environments in one certificate — the big one

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

**Cost of switching: 5 ALB rules and 0 DNS records.** It will never be cheaper.

### 3.2 `nAgent-*` has a capital letter

`nAgent-api-uat.bnprs.in` — the only mixed-case entry in the table, while `mGate` was
correctly lowercased to `mgate`.

DNS lookups are case-insensitive and so is ALB host-header matching, so this will
appear to work. The damage is elsewhere: the literal string propagates into OIDC
`redirect_uri` values (matched as an exact string), CORS origin comparisons
(case-sensitive in most frameworks), certificate SANs, and hand-written config — where
`nAgent` and `nagent` are two different values. Use lowercase.

Also settle **singular vs plural**: the table says `nAgent`, the infrastructure says
`nagents` (`nagents-uat-alb`, `nagents-uat-livekit-nlb`).

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
2. **SmartPresence API** — already has an ALB rule
   (`bnet-smartpresence-api-uat.bnprs.in`); the table only allows `bnet-api-uat`. This
   is the gap currently breaking bNet v2 (§4).
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
| **B — the target state** | Add DNS for `bnet-smartpresence-api-uat.bnprs.in` → `utms-shared-alb`, then point the app at it | Correct end state, and the ALB rule already exists. Needs the apex zone owner (`decisions.d7`) **and** confirmation that the listener presents a `*.bnprs.in` cert for that SNI name — the default cert on :443 is `*.itpgateway.com`, and a second cert is attached whose identity I did not get to verify. |
| **C — fold it in** | Serve SmartPresence under `bnet-api-uat.bnprs.in` on a path prefix | Most consistent with the table as written, but needs server-side routing changes and touches the Spring Boot app's `@RequestMapping`s. |

**Recommendation: A now, B as the target.** A restores service today without
prejudging `decisions.d1`; B lands once the scheme is ratified.

⚠️ Before B, verify the second SNI certificate on the `utms-shared-alb` :443 and :8443
listeners (`210edefa-cbda-4971-80cd-4a9a4e0280ce`). If it is not `*.bnprs.in`, every
`bnprs.in` host on that ALB will fail TLS the moment DNS is added — the same class of
error as the original mismatch, and the five existing rules are all waiting on it.

---

## 5. Provisioning plan

### Phase 0 — decisions (blocking, no AWS changes)

Nothing below can proceed safely without these. All are tracked in the registry's
`decisions:` block.

| id | decision | blocks |
|---|---|---|
| d7 | Who owns the `bnprs.in` apex zone, and which account writes its records? | **every record** |
| d1 | Flat or hierarchical environment labels? | the whole scheme |
| d3 | SmartPresence: own host, or path under `bnet-api`? | the bNet fix |
| d8 | Does auth migrate to `bnprs.in`? | auth + every client |
| d5 | Is bRuID a family or is wGate the product? `rengine`/`risk-engine`/`risk`? | 12 names |
| d2 | `nAgent` case, singular vs plural | 6 names |
| d4 | Explicit `-prod` token or bare name? | config policy |
| d6 | Which agent owns each AandhiPe surface? | 18 names |

### Phase 1 — restore bNet UAT

Option A from §4. One Route53 change, reversible, no certificate work.

### Phase 2 — certificate and listener preparation

1. Verify cert `210edefa-…` on `utms-shared-alb` :443 and :8443.
2. If `*.bnprs.in` is absent, attach it as an SNI certificate **before** any DNS.
3. If d1 goes hierarchical, request `*.uat.bnprs.in` and `*.sandbox.bnprs.in` and plan
   the delegations.

### Phase 3 — UAT records for what already exists

Only the five names with live ALB rules, once d1 and d7 are settled. Each one:
create record → `dig` → HTTPS probe → target health → flip registry status to `live`
with today's date. No batch changes; one name at a time.

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
