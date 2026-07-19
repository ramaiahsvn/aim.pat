# mGate India — CI image-build handoff (2026-07-19)

The India bootstrap is live in **891963159778 / ap-south-2**. Services infra is adapted and
planned but **held until container images exist** (operator decision 2026-07-19). This is what
the app/CI side needs to do to unblock the services deploy.

## Registry (push targets)

`891963159778.dkr.ecr.ap-south-2.amazonaws.com/<repo>`

Repos (all created, empty, tag-mutable):
mgate-prod-maingateway, mgate-prod-vendorstatus, mgate-prod-servicesotp, mgate-prod-servicesdb,
mgate-prod-otpstatus, mgate-prod-cloudwatch, mgate-prod-pipes, mgate-prod-mainqueueservice,
mgate-prod-callbackapplication, mgate-prod-processcallbacksfromfifo, mgate-prod-portalbackend

## CI auth — role ARNs unchanged from the Frankfurt convention

- **GitLab CI** (gitlab.bnprs.ai, project `BPR1002/bpr1002.mgate.api.2`, branch `bp_rel`):
  role `arn:aws:iam::891963159778:role/gitlab-mgate-prod-ecr-ecs-deploy` via GitLab OIDC
  (provider recreated 2026-07-19, same ARN). Role policies now scope to **ap-south-2** ECR and
  ECS cluster `mgate-in-prod-ecs-cluster`.
- **GitHub Actions** (`BNPRS/bpr1002.mgate.api.2` + `...api.2.portal`, branch `bp_rel`):
  role `arn:aws:iam::891963159778:role/github-mgate-prod-application-ecr-push` via GitHub OIDC
  (provider recreated 2026-07-19, same ARN).

**Pipeline change required:** registry region/URL only —
`eu-central-1` → `ap-south-2` (account unchanged). Role ARNs, repo names, branch filters unchanged.

## After images exist

Services stacks apply from `BPR1002/india/bpr1002.mgate.iaac` `services/*/prod` (India-adapted,
plans on file). ECS services deploy into cluster `mgate-in-prod-ecs-cluster`; service names keep
the `<service>-prod` convention (matches the CI deploy role's ARN allowlist).

## Also pending on the app side

- Real values for Secrets Manager placeholders: `mgate/appconfig/prod/mail-password`,
  subscriber default password, and the `mgate-in-prod` vendor-config secret (random placeholders
  were written by Terraform; set real values directly in Secrets Manager, ap-south-2).
- AppConfig content review: values seeded from the Iraq profile (VIP/blocked numbers, mPOS URLs
  `uat.itpgateway.link`, S3 `dr3` us-east-2) — India rollout needs its own values.
- Vendor NAT egress whitelisting: `16.113.17.34`, `16.113.60.29`.
