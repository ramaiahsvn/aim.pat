# mGate India — Fargate Cost Reduction Plan

**Account:** 891963159778 (`bnprs`) · **Region:** ap-south-2 · **Cluster:** `mgate-in-prod-ecs-cluster`
**Date:** 2026-07-30 · **Status:** PROPOSED — not applied, awaiting go-ahead
**Source of truth:** `~/BPR/GitRepos2/BPR1002_mGate_IN/bpr1002.mgate.iaac/services/<svc>/prod/terraform.tfvars` (branch `bp_rel`)

---

## 1. Why Fargate is the target

August projection is ~$1,683/mo. Fargate is **$952.72 — 57% of the entire bill**.

Current allocation: **14 services, 17 tasks, 25 vCPU, 50 GB**.

## 2. Measured utilisation (7 days, 2026-07-23 → 07-30)

Container Insights is **disabled**, but `AWS/ECS` still emits service-level `CPUUtilization` /
`MemoryUtilization` — no need to enable it (enabling would add cost).

| Service | Alloc CPU/Mem | CPU avg | CPU max | Peak CPU used | Mem max | Peak mem |
|---|---|---:|---:|---:|---:|---:|
| maingateway-prod ×4 | 2048 / 4096 | 0.26% | 9.46% | **194 u** | 11.88% | **487 MB** |
| pipes-prod | 2048 / 4096 | 0.25% | 2.83% | 58 u | 10.45% | 428 MB |
| pipes-2-prod | 2048 / 4096 | 0.32% | 1.30% | 27 u | 10.11% | 414 MB |
| pipes-3-prod | 2048 / 4096 | 0.31% | 0.96% | 20 u | 10.08% | 413 MB |
| pipes-4-prod | 2048 / 4096 | 0.30% | 1.46% | 30 u | 11.04% | 452 MB |
| servicesDb-prod | 1024 / 2048 | 0.79% | 14.40% | 147 u | 20.46% | 419 MB |
| otpStatus-prod | 1024 / 2048 | 0.73% | 8.90% | 91 u | 19.24% | 394 MB |
| callbackapplication-prod | 1024 / 2048 | 0.70% | 7.47% | 76 u | 20.43% | 418 MB |
| portalbackend-prod | 1024 / 2048 | 0.69% | 6.79% | 70 u | 22.07% | 452 MB |
| servicesOtp-prod | 1024 / 2048 | 0.74% | 6.78% | 69 u | 19.92% | 408 MB |
| processcallbacksfromfifo-prod | 1024 / 2048 | 0.76% | 6.39% | 65 u | 17.87% | 366 MB |
| vendorstatus-prod | 1024 / 2048 | 0.70% | 5.36% | 55 u | 18.26% | 374 MB |
| mainQueueService-prod | 1024 / 2048 | 0.73% | 4.18% | 43 u | 18.31% | 375 MB |
| cloudwatch-prod | 1024 / 2048 | 49.74% | 100.00% | — | 15.16% | — |

**Cluster-wide peak = 0.19 vCPU and 487 MB, in a 25 vCPU / 50 GB envelope.**
`cloudwatch-prod` is excluded — its numbers are a crash loop, not work (see §6).

### Traffic confirms it

7-day ALB request counts: maingateway **1,336**, portalbackend **5,149**, callbackapplication **2,802**
→ **~1,327 requests/day total (~0.9 req/min)** across the whole platform.

`maingateway-prod` spends ~8 vCPU (~$300/mo) serving **~191 requests a day**.

## 3. Root cause of the over-sizing

The tfvars comments are **wrong by a factor of 2**:

```hcl
cpu    = 2048  # 1 vCPU per task     <-- 2048 units IS 2 vCPU
memory = 4096  # 2 GB RAM per task   <-- 4096 MiB IS 4 GB
```

Whoever sized these believed they were allocating half what they actually were.

## 4. Phase 1 — Right-size (no architecture change)

Target: **2.5–5× headroom over measured peak**, autoscaling absorbs anything beyond.

| Service | CPU | Memory | desired | as_min | as_max | Headroom (CPU / mem) |
|---|---|---|---|---|---|---|
| maingateway | 2048→**512** | 4096→**1024** | 4→**2** | 4→**2** | 12→**8** | 2.6× / 2.1× |
| pipes, pipes-2, pipes-3, pipes-4 | 2048→**256** | 4096→**1024** | 1 | 1 | 8 | 4.4× / 2.3× |
| servicesDb | 1024→**512** | 2048→**1024** | 1 | 1 | 8 | 3.5× / 2.4× |
| otpStatus | 1024→**512** | 2048→**1024** | 1 | 1 | 8 | 5.6× / 2.6× |
| portalbackend | 1024→**256** | 2048→**1024** | 1 | 1 | 4 | 3.7× / 2.3× |
| callbackapplication | 1024→**256** | 2048→**1024** | 1 | 1 | 4 | 3.4× / 2.4× |
| servicesOtp | 1024→**256** | 2048→**1024** | 1 | 1 | 8 | 3.7× / 2.5× |
| processcallbacksfromfifo | 1024→**256** | 2048→**1024** | 1 | 1 | 4 | 3.9× / 2.8× |
| vendorstatus | 1024→**256** | 2048→**1024** | 1 | 1 | 8 | 4.7× / 2.7× |
| mainQueueService | 1024→**256** | 2048→**1024** | 1 | 1 | 8 | 6.0× / 2.7× |
| cloudwatch | unchanged — fix crash first (§6) | | | | | |

**25 vCPU / 50 GB → 5.5 vCPU / 16 GB.**

Tightest margin is maingateway memory at 2.1×. If that feels thin for a JVM, use
`memory = 2048` there — costs only **+$7/mo** and raises it to 4.2×.

### Cost

Effective ap-south-2 rates derived from actual billing (validates to within 0.01%):
`$0.042/vCPU-hr`, `$0.004609/GB-hr` → 25 vCPU + 50 GB = $952.66/mo vs $952.72 observed.

| | vCPU | GB | $/mo |
|---|---:|---:|---:|
| Now | 25.0 | 50 | **952.72** |
| After Phase 1 | 5.5 | 16 | **226.73** |
| **Saving** | | | **≈ $726/mo (76%)** |

### Critical: apply via Terraform, not the CLI

Live state matches the tfvars exactly. A CLI change would be reverted by the next
`terraform apply`. Also note `autoscaling_min_capacity = 4` on maingateway — **lowering
`desired_count` alone will not stick**; the min must come down too.

Four services have no autoscaling target at all (portalbackend, callbackapplication,
processcallbacksfromfifo, cloudwatch) — worth adding while in there.

## 5. Further phases

| Phase | Change | Monthly | Saving | Risk |
|---|---|---:|---:|---|
| 1 | Right-size | $227 | $726 | Low — 2.5–5× headroom, reversible |
| 2 | Fargate **Spot** for the 8 non-ALB workers | ~$110 | +$116 | Med — 2-min interruption notice; only for idempotent queue consumers |
| 3 | **ARM64/Graviton** (~20% off) | ~$88 | +$22 | Med — needs multi-arch images; Java usually trivial |
| 4 | Scheduled scale-down out-of-hours | ~$40 | +$48 | **Only if pre-launch** — see below |

Phase 2 keeps the three ALB-facing services (maingateway, portalbackend,
callbackapplication) on on-demand and moves the rest to Spot.

**Phase 4 depends on a question I can't answer from telemetry:** at 0.9 req/min, is this stack
serving real customers yet, or still pre-launch? If pre-launch, scheduled scale-to-zero
overnight and weekends is the single biggest remaining lever. If live, skip Phase 4 entirely.

### Sequencing warning

Do **not** buy a Compute Savings Plan before Phase 1 — you would commit 1–3 years to the
inflated 25 vCPU baseline. Right-size first, run two weeks, then evaluate a Savings Plan
against the *new* baseline.

## 6. `cloudwatch-prod` is broken and burning money

Crash-looping: restarts roughly every 90 seconds, `stoppedReason` = "Essential container in
task exited", **exit code 1**. That is the 49.74% avg CPU in the table — restart churn, not work.
It also inflates CloudWatch log ingest.

Either fix the container or set `desired_count = 0` until it is fixed. Owner: na-006/001
bpr1002-mgate-prod / dev team. This is an application defect, not infrastructure.

## 7. Consequence: cancel the Fargate quota request

Support case **178448041900761** (Fargate vCPU 6→50, partially granted at 30, auto-closed
2026-07-29) should **not** be re-filed.

At 25 of 30 vCPU the rolling-deploy ceiling was real — maingateway at `maximumPercent = 200`
needs +8 vCPU → 33 > 30, so the deploy would stall. After Phase 1 that same rolling deploy
needs **+1 vCPU on a 5.5 vCPU base**. The 30 ceiling stops being a constraint.

Fix the sizing instead of buying more quota.

## 8. Adjacent wins outside Fargate

| Item | Now | Proposed | Saving |
|---|---:|---|---:|
| Aurora `db.r5.large`, single-AZ | $249 | `db.t4g.medium` for this load | ~$190 |
| 3 × ALB for 1,327 req/day | $53 | 1 ALB, host-based routing | ~$35 |
| 2 × NAT gateway | $166 | 1 NAT, or S3/ECR VPC endpoints | ~$40 |

**Full path: $1,683/mo → roughly $600/mo.**

## 9. Recommended order

1. Fix or zero `cloudwatch-prod` (§6) — stops active waste, no sizing risk
2. Phase 1 right-size via Terraform, one service first (`pipes-3-prod`, lowest traffic) to
   validate, then the rest
3. Observe 48h — confirm no throttling, no OOM kills, no autoscale flapping
4. Aurora right-size (§8) — biggest single non-Fargate win
5. Reassess Spot / Graviton / Savings Plan against the new baseline

---

*Prepared by na-003/001 bnprs-aws. All utilisation figures measured from CloudWatch
`AWS/ECS` over 2026-07-23 → 07-30; all cost figures from Cost Explorer with
`RECORD_TYPE = Usage` (this account is credit-funded — unfiltered CE reads ~$0, see mem-013).*
