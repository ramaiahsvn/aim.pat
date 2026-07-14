# INPUT → na-003/005 bnprs-websites

**Routed by:** na-003/002 bnprs-aws-itp · **Date:** 2026-07-14 · **Priority:** normal · **Status:** OPEN

## Task
Build + deploy a **static website for `circletech.me`** on AWS. **GoDaddy stays the registrar** (no domain
transfer). Same S3+CloudFront+ACM pattern you already run for bnprs.ai/.in/.com — with one DNS variation (below).

## Architecture (decided with user, 2026-07-14)
```
circletech.me (apex)  --GoDaddy 301 forward-->  https://www.circletech.me
www.circletech.me     --GoDaddy CNAME-->        dXXXX.cloudfront.net  --OAC-->  S3 (private)
ACM cert (us-east-1)  =  HTTPS
```
- **S3 + CloudFront + ACM (HTTPS)** — chosen (not plain S3 website / HTTP).
- **DNS kept at GoDaddy** — user chose NOT to delegate NS to Route 53. This DIFFERS from the bnprs.ai
  pattern (which uses awsdns nameservers): here there is **no Route 53 hosted zone**. Instead:
  - `www` = **CNAME at GoDaddy** → CloudFront domain.
  - apex = **GoDaddy Domain Forwarding (301)** → `https://www.circletech.me` (GoDaddy can't ALIAS apex to CloudFront).

## Verified facts (bnprs-aws-itp)
- `.me` IS supported by Route 53 (transfer $31, incl. 1yr) — but we are **NOT transferring**, hosting only.
- No existing Route 53 hosted zone for circletech.me.
- ⚠️ **CONFIRM ACCOUNT:** user's original ask was "this account" = ITPCore **819144294008** (profile `itp`,
  us-east-2). Your bnprs.ai sites live in your usual account/region (ap-south-2). **Decide which AWS account
  hosts circletech.me** before building (ITP vs your standard). ACM for CloudFront MUST be in **us-east-1**.

## Build steps (your side)
1. Private **S3 bucket** (site content), tags `Project=ITPCore, Owner=bnprs, Environment=prod` (adjust Project if not ITP account).
2. **ACM cert** in **us-east-1** for `www.circletech.me` (+ `circletech.me`), DNS validation.
3. **CloudFront** dist: S3 origin via OAC, alias `www` (+apex), ACM cert, `index.html` root, HTTP→HTTPS redirect, PriceClass_100.
4. Bucket policy scoped to the CloudFront distribution (OAC).
5. Prefer **Terraform** (per aws-itp convention); show `plan` + cost before apply.

## Hand to user (at GoDaddy — you can't edit GoDaddy from here)
1. **ACM validation CNAME** (from the cert) — so it issues.
2. **CNAME `www` → `dXXXX.cloudfront.net`**.
3. **Forwarding `circletech.me` → `https://www.circletech.me`** (301).
> Sequencing: cert must validate (user step 1) BEFORE CloudFront can attach it — one hand-off pause mid-build.

## Open items
- **Site content:** user has not provided files yet — start with a placeholder `index.html` to validate the
  pipeline, or wait for real content? (confirm)
- **Account** (see ⚠️ above).

## Cost
No Route 53 hosted zone (DNS at GoDaddy). S3 ~pennies · ACM free · CloudFront ~free tier → **~$0–1/mo**.
