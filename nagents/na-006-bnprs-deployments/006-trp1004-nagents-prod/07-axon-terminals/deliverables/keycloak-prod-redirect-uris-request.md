# Request — Add nagents-PROD redirect URIs to `BNPRS-enterprise` clients

**To:** utms / shared-keycloak team (owners of `accounts-uat.itpgateway.com`, realm `BNPRS-enterprise`)
**From:** BNPRS deployments (nagents-prod / TRP1004)
**Date:** 2026-07-26
**Priority:** blocking — last gap before nagents-prod frontends are usable

---

## What we need

nagents **prod** is deployed in the ITP account (`819144294008`, ap-south-2). The prod frontends are live and serving on CloudFront, but **login bounces with a `redirect_uri` mismatch** because their prod origins aren't registered on the shared realm. Please **add** (append — keep the existing UAT entries) the following to the `BNPRS-enterprise` realm:

| Client | Add Valid Redirect URI | Add Web Origin |
|---|---|---|
| **`hr-spa`** (erp frontend) | `https://d393t8cl2frfgi.cloudfront.net/*` | `https://d393t8cl2frfgi.cloudfront.net` |
| **`projects-frontend`** | `https://d3gkxmmnojgivv.cloudfront.net/*` | `https://d3gkxmmnojgivv.cloudfront.net` |

If these clients use **post-logout redirect URIs**, please add the same two origins there too.

*(Custom prod frontend domains aren't set up yet — these are the CloudFront default domains. When custom domains land, we'll request those be added as well.)*

## Why we're asking you (couldn't self-serve)

We tried to apply this via the Admin API but don't have the access:
- The bootstrap admin password in Secrets Manager `utms/prod/keycloak` is **invalid** — it was rotated after first boot and the secret wasn't updated.
- The `hr-app-admin` service account returns **403** (scoped to user ops; no `manage-clients`).
- ECS exec is disabled on `utms-keycloak`, and there's no other admin secret.

## Fastest ways to resolve (any one)

1. **You make the 4 edits above** directly in the admin console (~2 min), **or**
2. **Update** `utms/prod/keycloak` → `KEYCLOAK_ADMIN_PASSWORD` with the current admin password, **or**
3. **Grant** the `hr-app-admin` service account the `manage-clients` realm-management role.

With option 2 or 3 we'll apply it ourselves immediately via the Admin API.

## Context

- Shared IdP: `https://accounts-uat.itpgateway.com`, realm `BNPRS-enterprise` (used by nagents apps for auth).
- nagents-prod backends already authenticate against this realm; only the frontend redirect URIs are missing.

Thank you — once added, nagents-prod frontends complete login and the platform is fully functional.
