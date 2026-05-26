# Skill: Deploy Static Site to S3 + CloudFront

## Purpose

Build an Astro site and deploy it to AWS S3 with CloudFront cache invalidation.

## When to use

Load this skill whenever the user asks to deploy, publish, release, or update any of the managed websites.

## Commands

### 1. Build
```bash
cd <source_path>
npm install
npm run build
```

### 2. Verify build
```bash
test -f <source_path>/dist/index.html && echo "Build OK" || echo "Build FAILED"
```

### 3. Sync to S3
```bash
aws --profile bnprs s3 sync <source_path>/dist/ s3://<bucket> --delete --region ap-south-2
```

### 4. Invalidate CloudFront
```bash
aws --profile bnprs cloudfront create-invalidation \
  --distribution-id <cloudfront_id> \
  --paths '/*'
```

### 5. Verify live
```bash
curl -s -o /dev/null -w '%{http_code}' https://<domain>
```

## Domain → Bucket → CloudFront map

| Domain | Source | S3 Bucket | CloudFront ID |
|--------|--------|-----------|---------------|
| bnprs.ai | BPR2004_Design/bpr2004.bnprs.ai | bnprs-ai-fe | EHKEPP01C2TFV |
| bnprs.in | BPR2004_Design/bpr2004.bnprs.in | bnprs-in-fe | E1SC03F64TLZZ0 |
| bnprs.com | BPR2004_Design/bpr2004.bnprs.com | bnprs-com-fe | EIRPPLAXGKOQA |

## Rules

- Always run preflight (AWS creds + S3 reachable) before build
- Always confirm with user before S3 sync (production)
- Always invalidate CloudFront after every sync
- Write deployment record to `07-axon-terminals/deliverables/deployment-reports/`
