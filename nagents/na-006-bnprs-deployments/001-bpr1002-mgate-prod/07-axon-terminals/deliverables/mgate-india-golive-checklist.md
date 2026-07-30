# mGate India — Go-Live Rebuild Checklist

**Status:** ⏸️ PAUSED — infrastructure torn down 2026-07-30, resume when the project goes live
**Account:** 891963159778 (`bnprs`) · **Region:** ap-south-2
**IaC:** `~/BPR/GitRepos2/BPR1002_mGate_IN/bpr1002.mgate.iaac`, branch `bp_rel` (`766706b`)
**Context:** mem-017 (teardown record) · mem-018 (destroy blockers) · `fargate-cost-reduction-plan.md` (sizing spec)

> Estimated rebuild time: **1–2 hours**. Nothing here is blocked by AWS — everything needed
> was deliberately retained.

---

## 0 · Before you start

- [ ] Check **remaining AWS credit balance** — Billing → Credits (no API for this). This decides
      whether the rebuild should be cost-optimised aggressively or not.
- [ ] Confirm the DB snapshot still exists and is `available`:
      `aws rds describe-db-cluster-snapshots --snapshot-type manual --region ap-south-2 --profile bnprs`
      → expect `mgate-in-prod-db-preteardown-20260730` (~67 MB, tagged `Retain=true`)
- [ ] `git pull` the IaC repo; confirm `bp_rel` is at `766706b` or later
- [ ] Confirm the 18 ECR repos still hold the images the service tfvars pin
      (`services/*/prod/terraform.tfvars` pin image tags to built SHAs)
- [ ] Confirm ACM certs are still ISSUED: `api.mgate.bnprs.in` (df684416),
      `*.mgate.bnprs.in` (623a1971)

## 1 · Sizing changes to make BEFORE the first apply

**Do not re-apply the old tfvars.** The stack was built at 25 vCPU / 50 GB while peaking at
**0.19 vCPU** — a ~130× over-provision costing $953/mo. Full rationale and measurements in
`fargate-cost-reduction-plan.md` §2–§4.

- [ ] `maingateway`: cpu `2048→512`, memory `4096→1024`, desired `4→2`, as_min `4→2`, as_max `12→8`
- [ ] `pipes`, `pipes-2`, `pipes-3`, `pipes-4`: cpu `2048→256`, memory `4096→1024`
- [ ] `servicesDb`, `otpStatus`: cpu `1024→512`, memory `2048→1024`
- [ ] `portalbackend`, `callbackapplication`, `mainQueueService`, `processcallbacksfromfifo`,
      `vendorstatus`, `servicesOtp`: cpu `1024→256`, memory `2048→1024`
- [ ] Fix the misleading comments in every tfvars — `cpu = 2048  # 1 vCPU per task` is **wrong**,
      2048 units is 2 vCPU. This off-by-2× comment is how the over-sizing crept in originally.
- [ ] Add autoscaling targets for the 4 services that have none: `portalbackend`,
      `callbackapplication`, `processcallbacksfromfifo`, `cloudwatch`

**Result: 25 vCPU / 50 GB → 5.5 vCPU / 16 GB ($953 → ~$227/mo).**

## 2 · Drop the VPC interface endpoints

Seven endpoints cost **$116.06/mo** — the single most expensive thing nobody noticed, and the
*same* mistake mem-011 recorded in Frankfurt before it repeated in India.

- [ ] **Keep** the S3 *gateway* endpoint (`com.amazonaws.ap-south-2.s3`) — gateway endpoints are free
- [ ] **Drop** the 6 *interface* endpoints (sqs, logs, appconfigdata, ecr.dkr, ecr.api,
      secretsmanager) unless traffic genuinely justifies them — NAT already provides egress
- [ ] Revisit only if NAT data-processing charges exceed the endpoint cost (they were $0.05/mo,
      so this is unlikely for a long time)

## 3 · Database

- [ ] Set `db_snapshot_identifier = "mgate-in-prod-db-preteardown-20260730"` in
      `platform/prod/terraform.tfvars` so the rebuild restores rather than starting empty
- [ ] Consider `db.t4g.medium` instead of `db.r5.large` — ~$190/mo saving; the r5.large was
      never remotely loaded. Scale up when real traffic justifies it.
- [ ] Leave `deletion_protection = true` and `skip_final_snapshot = false` as they are in the repo
      (correct for a live stack — they were only flipped temporarily during teardown)

## 4 · Apply order

- [ ] `platform/prod` first — owns the VPC, subnets, Aurora, ECS cluster, secrets
- [ ] then the service stacks (any order; `sqs-scaler` has no resources)
- [ ] Expect ~79 resources in platform, ~13 per service stack

## 5 · Post-rebuild verification

- [ ] All ECS services reach steady state; no task flapping
- [ ] **Fix `cloudwatch-prod`** — it was crash-looping before teardown (exit code 1, restart every
      ~90s, "Essential container in task exited"). Application defect, owner na-006/001 / dev team.
      Do not redeploy it broken.
- [ ] Confirm DNS resolves and ALBs pass health checks
- [ ] Check Fargate vCPU usage against the quota — **30 is ample at the new sizing.**
      Do **not** re-file support case 178448041900761 for 50 (see mem-016)
- [ ] Verify the restored DB has the expected schema and data

## 6 · Cost guardrails to put in place THIS time

The previous run went from $175/mo to $1,683/mo in two months with nothing alerting, because
this account is **fully credit-funded** and every default cost view reads ~$0 (mem-013).

- [ ] Fix budget `MonthlyBudget` — currently $10 with `IncludeCredit: true`, so it tracks *net*
      (~$0) and is **structurally incapable of ever firing**. Set `IncludeCredit: false` and a
      realistic limit, or delete it.
- [ ] Re-tier `monthly-250-alert` to something meaningful for the new baseline
- [ ] Any cost query in this account **must** filter `RECORD_TYPE=Usage`, else it reads as free:
      `--filter '{"Dimensions":{"Key":"RECORD_TYPE","Values":["Usage"]}}'`
- [ ] Do **not** buy a Compute Savings Plan until the new baseline has run 2 weeks

## 7 · Housekeeping — not blocking, can be done any time

- [x] ~~Release idle EIPs in **eu-central-1**~~ — **DONE 2026-07-30.** All three released
      (`63.182.201.159`, `3.126.247.176`, `3.74.90.58`) and the vestigial `bootstrap/eip` stack
      deleted outright. eu-central-1 now holds **zero** EIPs (~$11/mo saved). See na-003/001
      mem-019 / mem-020. **Consequence for a rebuild:** there is no longer any pre-allocated EIP
      to inherit — `modules/network/vpc` self-allocates NAT EIPs, which is what India already does.
- [ ] Clean up remaining Frankfurt leftovers: portal-frontend CloudFront, old state bucket, SQS,
      AppConfig (dead since the June teardown, mem-012)
- [x] ~~Delete orphaned SSM SecureStrings in eu-central-1~~ — **DONE 2026-07-30.**
      `/mgate-prod-vpn/wireguard/client{1,2}.conf`. Dead key material for a server destroyed
      2026-06-14; they embed the now-released `3.74.90.58`.
- [ ] Delete `mgate-in-prod-db-preteardown-20260730` **only after** a successful restore is verified
- [ ] Move the plaintext vendor creds out of `bootstrap/vendor-config/{prod,uat}/main.tf` and purge
      git history (long-standing security debt, mem-008)

---

## What is still running and costing money

| Item | $/mo | Owner |
|---|---:|---|
| `gitlab-server` t3.large | ~66 (with perso-bureau) | na-003/003 |
| `perso-bureau-uat` t4g.small | ↑ | na-005/010 |
| EBS volumes + snapshots | ~19 | mixed |
| ~~Frankfurt idle EIPs ×3~~ | ~~11~~ → **0** | released 2026-07-30 |
| SQS / AppConfig / Secrets / ECR (bootstrap) | ~37 | mGate bootstrap |
| **Total** | **≈ 129** | |

## What is preserved and ready

18 ECR repos · 16 SQS queues · 7 Secrets Manager secrets · 2 ACM certs · Terraform state bucket
`mgate-in-prod-terraform-state` · bootstrap appconfig / vendor-config / portal-frontend ·
DB snapshot `mgate-in-prod-db-preteardown-20260730`

> `bootstrap/eip` is **gone** — deleted 2026-07-30, not merely emptied. Do not expect it back;
> `modules/network/vpc` self-allocates NAT EIPs, which is already how India was configured.

---

*na-003/001 bnprs-aws · created 2026-07-30 · resume trigger: mGate India go-live*
