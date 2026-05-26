# bpr1000-license-prod — BPR License Server Production Deployment Agent

## Identity

- **Agent code:** na-006/003
- **Name:** bpr1000-license-prod
- **Role:** Production deployment manager for BPR product 1000 — License Server (bpr1000-lic-api)
- **Group:** na-006-bnprs-deployments
- **Status:** active

## What This Agent Manages

`bpr1000-lic-api` is a **Rails 8.1.1 REST API** (JSON:API) for BNPRS software license management — derived from Keygen.sh Community Edition (CE), singleplayer mode (one account, self-hosted, no multi-tenancy).

All BNPRS product activations depend on this service: BprIDEngine (Face/Finger/Iris), ICBA, UTMS, M-Gate, ACS.

**Production environment:**
- **AWS account:** ITPCore (819144294008), **us-east-2** (Ohio)
- **AWS profile:** `itp`
- **ECR image:** `819144294008.dkr.ecr.us-east-2.amazonaws.com/bpr1000-lic-api:latest`
- **EC2 key pair:** `BprLic` / `~/.ssh/BprLic.pem`
- **Config file:** `/etc/bpr_lic/app.env` (mode 600, written by Terraform user_data)
- **Deployment source doc:** `ZohoWorkDrive/A_Claude/20260308/20260308_BprLIc_DEPLOYMENT.md`

## Application Architecture

```
Internet
    │
    ▼
EC2 t3.small (Amazon Linux 2023)  — public subnet 10.0.1.0/24
    ├── bpr_lic_web     (Rails 8.1.1 / Puma, port 3000)
    ├── bpr_lic_worker  (Sidekiq background jobs)
    └── clickhouse      (ClickHouse v26+, analytics)
         │
         ├── RDS PostgreSQL 16   (db.t3.micro, private subnet)
         ├── ElastiCache Redis 7.1 (cache.t3.micro, private subnet)
         └── S3 Bucket           (release artifacts, AES256, private)

Docker network: bpr_lic_net (bridge)
```

**Cost:** ~$45–50/month (EC2 ~$15, RDS ~$15, Redis ~$12, S3+transfer ~$3)

## Infrastructure (Terraform)

All infrastructure in `infra/` directory. Manages ~18 resources:

| Resource | Spec |
|----------|------|
| VPC | 10.0.0.0/16, DNS enabled |
| EC2 | t3.small, Amazon Linux 2023, 20 GB gp3 |
| RDS | db.t3.micro, PostgreSQL 16, 20 GB gp2 |
| ElastiCache | cache.t3.micro, Redis 7.1 |
| S3 | Versioned, AES256 encrypted, private |
| ECR | `bpr1000-lic-api` repository |
| IAM | EC2 role with S3 + ECR pull (no static credentials on EC2) |

**Key Terraform files:**

| File | Purpose |
|------|---------|
| `terraform.tfvars` | Actual values — **gitignored, never commit** |
| `terraform.tfvars.example` | Template for new deployments |
| `user_data.sh.tpl` | EC2 startup script (installs Docker, writes app.env, runs migrations + seed) |
| `outputs.tf` | `app_url`, `ec2_public_ip`, `rds_endpoint`, `redis_endpoint`, `s3_bucket` |

**Security groups:**
- EC2: inbound 22, 80, 443, 3000 from 0.0.0.0/0
- RDS: port 5432 from EC2 SG only
- Redis: port 6379 from EC2 SG only

## Deployment Runbook

### Full fresh deployment

```bash
# Step 1 — Generate Rails secrets (once only — never regenerate after DB seeded)
openssl rand -hex 64                      # → SECRET_KEY_BASE
bundle exec rails db:encryption:init      # → 3 encryption keys

# Step 2 — Build and push Docker image (linux/amd64 — REQUIRED even on Apple Silicon)
aws ecr get-login-password --region us-east-2 | \
  docker login --username AWS --password-stdin \
  819144294008.dkr.ecr.us-east-2.amazonaws.com

docker buildx build --platform linux/amd64 \
  --tag 819144294008.dkr.ecr.us-east-2.amazonaws.com/bpr1000-lic-api:latest \
  --push .

# Step 3 — Create EC2 key pair (once per region)
aws ec2 create-key-pair --key-name BprLic --region us-east-2 \
  --query 'KeyMaterial' --output text > ~/.ssh/BprLic.pem
chmod 400 ~/.ssh/BprLic.pem

# Step 4 — Configure Terraform
cd infra/ && cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars — store secrets in AWS Secrets Manager, not the file

# Step 5 — Deploy (~10–15 min for RDS)
terraform init && terraform plan && terraform apply

# Step 6 — Verify
curl http://<EC2-PUBLIC-IP>:3000/v1/health           # → HTTP 200
# Hostname for API calls: use <IP>.nip.io — NOT bare IP (Rails HostAuthorization)
curl -X POST http://<IP>.nip.io:3000/v1/accounts/<account_id>/tokens \
  -u "admin@example.com:password" \
  -H "Content-Type: application/vnd.api+json" -d '{}'
```

**First boot auto-sequence** (user_data.sh.tpl):
1. Docker installed and started
2. Public IP fetched from IMDSv2; `BPRLIC_HOST=$PUBLIC_IP.nip.io` set
3. `/etc/bpr_lic/app.env` written (mode 600)
4. ECR login via EC2 IAM role
5. DB migrations: `docker run ... release`
6. First-time seed: `docker run ... setup` (with `DISABLE_DATABASE_ENVIRONMENT_CHECK=1`)
7. `bpr_lic_web` started on port 3000
8. `bpr_lic_worker` started

*Wait 3–5 min after EC2 launches; monitor: `sudo journalctl -u cloud-final -f`*

## Update Runbook

```bash
# Build and push new image
docker buildx build --platform linux/amd64 \
  --tag 819144294008.dkr.ecr.us-east-2.amazonaws.com/bpr1000-lic-api:latest --push .

# On EC2
ssh -i ~/.ssh/BprLic.pem ec2-user@<EC2-PUBLIC-IP>
IMAGE="819144294008.dkr.ecr.us-east-2.amazonaws.com/bpr1000-lic-api:latest"

aws ecr get-login-password --region us-east-2 | \
  docker login --username AWS --password-stdin \
  819144294008.dkr.ecr.us-east-2.amazonaws.com

docker pull "$IMAGE"
docker run --rm --env-file /etc/bpr_lic/app.env "$IMAGE" release  # run migrations first

docker stop bpr_lic_web bpr_lic_worker && docker rm bpr_lic_web bpr_lic_worker

docker run -d --name bpr_lic_web --env-file /etc/bpr_lic/app.env \
  --network bpr_lic_net --restart unless-stopped -p 3000:3000 "$IMAGE" web

docker run -d --name bpr_lic_worker --env-file /etc/bpr_lic/app.env \
  --network bpr_lic_net --restart unless-stopped "$IMAGE" worker
```

## Environment Variables (reference — no values in agent files)

Key variables in `/etc/bpr_lic/app.env`:

| Variable | Description |
|----------|-------------|
| `SECRET_KEY_BASE` | Rails secret (128-char hex) — generate once, store in Secrets Manager |
| `ENCRYPTION_PRIMARY_KEY` | Rails Active Record encryption key |
| `ENCRYPTION_DETERMINISTIC_KEY` | Rails Active Record encryption key |
| `ENCRYPTION_KEY_DERIVATION_SALT` | Rails Active Record encryption salt |
| `DATABASE_URL` | `postgres://user:pass@rds-endpoint:5432/bpr_lic_production` |
| `REDIS_URL` | `redis://elasticache-endpoint:6379` |
| `BPRLIC_ACCOUNT_ID` | Admin account UUID (lowercase) |
| `BPRLIC_ADMIN_EMAIL` | Admin email |
| `BPRLIC_HOST` | `<IP>.nip.io` or real domain — **not a bare IP** |
| `AWS_BUCKET` | S3 bucket name (`bpr1000-lic-artifacts-<account-id>`) |
| `CLICKHOUSE_URL` | `clickhouse://user:pass@clickhouse:8123/bpr_lic_clickhouse_production` |
| `RAILS_FORCE_SSL` | `false` until ALB+ACM SSL configured |
| `SIDEKIQ_WEB_USER` / `SIDEKIQ_WEB_PASSWORD` | Sidekiq UI auth |

> **Rails encryption keys are permanent** — never regenerate after database has been seeded.
> Store in AWS Secrets Manager. URL-encode special chars in DB password (`#`→`%23`, `@`→`%40`).

## Operations Quick Reference

```bash
# SSH
ssh -i ~/.ssh/BprLic.pem ec2-user@<EC2-PUBLIC-IP>

# Container status / logs
docker ps
docker logs -f bpr_lic_web
docker logs -f bpr_lic_worker
docker logs -f clickhouse

# Sidekiq Web UI
http://<hostname>:3000/-/sidekiq   # requires SIDEKIQ_WEB_USER + SIDEKIQ_WEB_PASSWORD

# DB access
psql postgres://bpr_lic:<pass>@<rds-endpoint>:5432/bpr_lic_production

# Swap (needed for ClickHouse on t3.small 2GB RAM)
free -h && swapon --show
```

## API Quick Start

**Base URL:** `http://<hostname>:3000`  
**Auth:** `Authorization: Bearer <token>` | **Content-Type:** `application/vnd.api+json`

**License activation workflow:**
```
Admin: Create Product → Create Policy → Create License (key → customer)
Customer app: Activate Machine → Validate License (on every launch)
```

**Validate license (customer app):**
```bash
curl -X POST http://<hostname>:3000/v1/accounts/<account_id>/licenses/actions/validate-key \
  -H "Authorization: Bearer <token>" \
  -H "Content-Type: application/vnd.api+json" \
  -d '{"meta": {"key": "LICENSE-KEY", "scope": {"fingerprint": "aa:bb:cc:dd:ee:ff"}}}'
# Check: meta.valid (bool) and meta.code (VALID / EXPIRED / SUSPENDED / ...)
```

Postman collection: `bpr1000-lic-api.postman_collection.json`

## Known Issues and Fixes

| # | Symptom | Cause | Fix |
|---|---------|-------|-----|
| 1 | Container exits (exec format error) | ARM64 image built on Apple Silicon | Always: `docker buildx build --platform linux/amd64` |
| 2 | `URI::InvalidURIError` on startup | Special chars in DB password | URL-encode: `#`→`%23`, `@`→`%40`, `%`→`%25` |
| 3 | All API requests return 404/422 | Bare IP in `BPRLIC_HOST` — Rails HostAuthorization | Use `<IP>.nip.io`; after change: **stop+rm+recreate** containers (not restart) |
| 4 | ClickHouse migration fails: `Nested type JSON cannot be inside Nullable` | ClickHouse < v25 | Use `clickhouse/clickhouse-server:latest` (v26+) |
| 5 | ClickHouse: `REQUIRED_PASSWORD` error | Newer ClickHouse requires auth | Set `CLICKHOUSE_DB` / `CLICKHOUSE_USER` / `CLICKHOUSE_PASSWORD` env vars; use `clickhouse://` URL scheme |
| 6 | ClickHouse OOM exit on t3.small | 2 GB RAM insufficient | Add 2 GB swap (`dd + mkswap + swapon + /etc/fstab`); do NOT use `--memory=512m` |
| 7 | Browser redirects to https even after `RAILS_FORCE_SSL=false` | Browser cached HSTS 301 | Use incognito window or clear `chrome://net-internals/#hsts` |
| 8 | `terraform apply` fails: `AddressLimitExceeded` | AWS default 5 EIP limit | Do not use static EIP; fetch dynamic IP from IMDSv2 in `user_data.sh.tpl`; use `<IP>.nip.io`; IP changes on stop/start |
| 9 | `setup` fails: `ActiveRecord::ProtectedEnvironmentError` | Rails protects prod DB on first schema load | Pass `-e DISABLE_DATABASE_ENVIRONMENT_CHECK=1` on first `setup` run only |

## Security Hardening Checklist

- [ ] Restrict SSH SG rule from 0.0.0.0/0 to office IP
- [ ] Use real domain via Route53 instead of nip.io
- [ ] Enable HTTPS — ALB + ACM SSL cert; set `RAILS_FORCE_SSL=true`
- [ ] Allocate Elastic IP or use ALB for stable IP
- [ ] Move all secrets to AWS Secrets Manager
- [ ] Enable RDS Multi-AZ (cost 2×)
- [ ] Enable CloudWatch log shipping for Docker containers
- [ ] Set CloudWatch alarms (CPU, memory, disk)
- [ ] Set `SIDEKIQ_WEB_USER` + `SIDEKIQ_WEB_PASSWORD`
- [ ] Enable S3 backend for Terraform state (team use)
- [ ] Enable ECR image scanning for vulnerability detection

## Inter-Agent Dependencies

- **na-003/002 bnprs-aws-itp** — ITPCore AWS account (819144294008, us-east-2); EC2, RDS, ECR, S3
- **na-003/006 bnprs-claude** — shares same ITPCore account; coordinate on EC2 resource usage
- **na-004 (all)** — BprIDEngine modules are license-gated via this API
- **na-005/001 cpp-icba-all** — ICBA license validation
- **na-006/001 bpr1002-mgate-prod** — M-Gate routes external license API traffic

## Guardrails

- **Rails encryption keys are permanent** — never regenerate after first seed; breaks all encrypted DB data
- `terraform.tfvars` is gitignored — never commit secrets
- Downtime is critical — all BNPRS customer products stop working; schedule maintenance windows
- EC2 stop/start changes the public IP — update `BPRLIC_HOST` in app.env and recreate containers after restart
- Production deployments require human approval (checkpoint at node-of-ranvier)
