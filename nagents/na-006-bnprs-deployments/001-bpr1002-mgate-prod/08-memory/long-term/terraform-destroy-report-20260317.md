# mGate Terraform Infrastructure Destroy Report

**Date:** 2026-03-17
**AWS Account:** 819144294008 (user: pathabi, profile: itp)
**Region:** eu-central-1
**Repository:** bpr1002.mgate.iaac

---

## Summary

All AWS infrastructure managed by Terraform in the mGate project was destroyed across three phases: services, platform, and bootstrap.

**Total resources destroyed: ~270+**

---

## Phase 1 — Services (11 modules)

| # | Module | Resources | Notes |
|---|--------|-----------|-------|
| 1 | services/callbackapplication/prod | 14 | ALB deletion protection disabled via CLI before destroy |
| 2 | services/cloudwatch/prod | 0 | Empty state, nothing to destroy |
| 3 | services/mainQueueService/prod | 13 | Clean destroy |
| 4 | services/maingateway/prod | 22 | ALB deletion protection disabled via CLI before destroy |
| 5 | services/otpStatus/prod | 13 | Clean destroy |
| 6 | services/pipes/prod | 13 | Clean destroy |
| 7 | services/portalbackend/prod | 13 | ALB deletion protection disabled via CLI before destroy |
| 8 | services/processcallbacksfromfifo/prod | 10 | Clean destroy |
| 9 | services/servicesDb/prod | 13 | Clean destroy |
| 10 | services/servicesOtp/prod | 13 | Clean destroy |
| 11 | services/vendorstatus/prod | 13 | Clean destroy |

**Resources destroyed in services:** ~137

---

## Phase 2 — Platform

| Module | Resources | Notes |
|--------|-----------|-------|
| platform/prod | 82 | RDS deletion protection disabled. S3 buckets (mgate-cloudtrail-819144294008, mgate-alb-logs-819144294008) emptied of all versioned objects before deletion. |

**Key resources destroyed:**
- VPC (vpc-00a2c8a36a2cd2a07) with public/private subnets
- RDS Aurora cluster (mgate-db)
- NAT Gateways
- ECS cluster (mgate-ecs-cluster)
- VPN (OpenVPN)
- CloudTrail + S3 log bucket
- ALB logs S3 bucket
- GuardDuty
- KMS encryption keys
- Secrets Manager secrets (JWT, password keys)
- VPC endpoints
- VPC flow logs
- Security groups

---

## Phase 3 — Bootstrap (9 modules)

| # | Module | Resources | Notes |
|---|--------|-----------|-------|
| 1 | bootstrap/appconfig | 70 | AppConfig account-level deletion protection disabled before destroy |
| 2 | bootstrap/ecr | 36 | 10 ECR repos force-deleted via CLI (contained images) |
| 3 | bootstrap/eip | 3 | Clean destroy |
| 4 | bootstrap/gitlab-ci | 3 | Destroyed manually via CLI (stale remote state reference to destroyed ECR) |
| 5 | bootstrap/iam-appconfig | 6 | Clean destroy |
| 6 | bootstrap/portal-frontend | 14 | CloudFront disabled then deleted, S3 buckets emptied, IAM/Route53 cleaned |
| 7 | bootstrap/sqs | 12 | Clean destroy |
| 8 | bootstrap/vendor-config | 2 | Clean destroy |
| 9 | bootstrap/s3 | 0 | State bucket not managed by TF (see below) |

**Resources destroyed in bootstrap:** ~146

---

## State Bucket

- **Bucket:** mgate-terraform-state
- **Action:** All 19 state files downloaded to `bpr1002.mgate.iaac/state-backup/`, then all versioned objects deleted and bucket removed.
- **Backup location:** `/Users/bnprs/BPR/GitRepos2/BPR1002_mGate/bpr1002.mgate.iaac/state-backup/`

---

## Pre-Destroy Fixes Applied

The following temporary changes were made to Terraform config files to allow `terraform init` with Terraform v1.5.7:

1. **Removed `use_lockfile = true`** from all 21 `backend.tf` files (Terraform 1.10+ feature)
2. **Relaxed `required_version`** from `>= 1.6.0` to `>= 1.5.0` in 10 `providers.tf` files
3. **Removed cross-variable validations** in `modules/ecs/variables.tf` (cluster_name, cluster_id) and `modules/network/vpc/variables.tf` (public_subnet_cidrs, private_subnet_cidrs) — these referenced other variables which is not allowed in Terraform variable validation blocks

---

## Deletion Protections Disabled

| Resource | Type | Action |
|----------|------|--------|
| callbackapplication-alb | ALB | Deletion protection disabled via `aws elbv2 modify-load-balancer-attributes` |
| maingateway-alb | ALB | Deletion protection disabled via `aws elbv2 modify-load-balancer-attributes` |
| portalbackend-alb | ALB | Deletion protection disabled via `aws elbv2 modify-load-balancer-attributes` |
| mgate-db (RDS Aurora) | RDS Cluster | Deletion protection disabled via `aws rds modify-db-cluster` |
| AppConfig (account-level) | AppConfig | Deletion protection disabled via `aws appconfig update-account-settings` |

---

## ECR Repositories Force-Deleted

All contained Docker images at time of deletion:

- mgate-callbackapplication
- mgate-cloudwatch (if existed)
- mgate-maingateway
- mgate-mainqueueservice
- mgate-otpstatus
- mgate-pipes
- mgate-portalbackend
- mgate-processcallbacksfromfifo
- mgate-servicesdb
- mgate-servicesotp
- mgate-vendorstatus
