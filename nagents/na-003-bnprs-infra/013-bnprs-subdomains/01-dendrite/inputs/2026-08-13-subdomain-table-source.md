# Input — proposed bnprs.in subdomain table

**From:** user · **Date:** 2026-08-13 · **Status:** source of record for the naming standard

Reproduced verbatim as given. Corrections belong in
`01-dendrite/connectors/subdomain-registry.yaml`, not here — this file is the
unedited input so later disagreements can be traced to what was actually asked for.

| Product | Sandbox | Uat | Production |
|---|---|---|---|
| Utms | utms-api-sandbox.bnprs.in | utms-api-uat.bnprs.in | utms-api.bnprs.in |
| | utms-portal-sandbox.bnprs.in | utms-portal-uat.bnprs.in | utms-portal.bnprs.in |
| BNet | bnet-api-sandbox.bnprs.in | bnet-api-uat.bnprs.in | bnet-api.bnprs.in |
| | bnet-portal-sandbox.bnprs.in | bnet-portal-uat.bnprs.in | bnet-portal.bnprs.in |
| AandhiPe Mobile | aandhipe-mobile-api-sandbox.bnprs.in | aandhipe-mobile-api-uat.bnprs.in | aandhipe-mobile-api.bnprs.in |
| | aandhipe-mobile-portal-sandbox.bnprs.in | aandhipe-mobile-portal-uat.bnprs.in | aandhipe-mobile-portal.bnprs.in |
| AandhiPe mPos | aandhipe-mpos-api-sandbox.bnprs.in | aandhipe-mpos-api-uat.bnprs.in | aandhipe-mpos-api.bnprs.in |
| | aandhipe-mpos-portal-sandbox.bnprs.in | aandhipe-mpos-portal-uat.bnprs.in | aandhipe-mpos-portal.bnprs.in |
| AandhiPe Kiosk | aandhipe-kiosk-api-sandbox.bnprs.in | aandhipe-kiosk-api-uat.bnprs.in | aandhipe-kiosk-api.bnprs.in |
| | aandhipe-kiosk-portal-sandbox.bnprs.in | aandhipe-kiosk-portal-uat.bnprs.in | aandhipe-kiosk-portal.bnprs.in |
| bRuID ACS | bruid-acs-api-sandbox.bnprs.in | bruid-acs-api-uat.bnprs.in | bruid-acs-api.bnprs.in |
| | bruid-acs-portal-sandbox.bnprs.in | bruid-acs-portal-uat.bnprs.in | bruid-acs-portal.bnprs.in |
| bRuID wGate | bruid-wgate-api-sandbox.bnprs.in | bruid-wgate-api-uat.bnprs.in | bruid-wgate-api.bnprs.in |
| | bruid-wgate-portal-sandbox.bnprs.in | bruid-wgate-portal-uat.bnprs.in | bruid-wgate-portal.bnprs.in |
| bRuID rEngine | bruid-rengine-api-sandbox.bnprs.in | bruid-rengine-api-uat.bnprs.in | bruid-rengine-api.bnprs.in |
| | bruid-rengine-portal-sandbox.bnprs.in | bruid-rengine-portal-uat.bnprs.in | bruid-rengine-portal.bnprs.in |
| bRuID Pass | bruid-pass-api-sandbox.bnprs.in | bruid-pass-api-uat.bnprs.in | bruid-pass-api.bnprs.in |
| | bruid-pass-portal-sandbox.bnprs.in | bruid-pass-portal-uat.bnprs.in | bruid-pass-portal.bnprs.in |
| nAgent | nAgent-api-sandbox.bnprs.in | nAgent-api-uat.bnprs.in | nAgent-api.bnprs.in |
| | nAgent-portal-sandbox.bnprs.in | nAgent-portal-uat.bnprs.in | nAgent-portal.bnprs.in |
| mGate | mgate-api-sandbox.bnprs.in | mgate-api-uat.bnprs.in | mgate-api.bnprs.in |
| | mgate-portal-sandbox.bnprs.in | mgate-portal-uat.bnprs.in | mgate-portal.bnprs.in |

**As given: 11 products × 2 components × 3 environments = 66 hostnames.**

Note the source writes nAgent with a capital **A** while mGate is lowercased to
`mgate`. Carried through above exactly as received; see registry `decisions.d2`.

The user's framing: *"I might correct or add new domains"* — so this table is a
starting point, not a frozen spec. The registry YAML is the file to edit.
