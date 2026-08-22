#!/bin/bash
# One-shot GFF deploy: API image (build local amd64 -> ECR) -> ECS rolling deploy
# (preserves current env: FACECHAIN_MODE=SERVER + 4GB, only the image changes) ->
# portal to S3 + CloudFront. Mirrors the CI jobs exactly; CI runner is offline.
set -euo pipefail
REGION=eu-central-1; PROFILE=itp
ECR=819144294008.dkr.ecr.eu-central-1.amazonaws.com/utms-smartpresence-api

echo "=== 1/3 build + push API image ==="
bash "$(dirname "$0")/build-smartpresence-image.sh"
cd "$HOME/BPR/GitRepos2/BPR1004_uTms/bpr1004.utms.api.bnet.smartpresence"
SHA=$(git rev-parse HEAD)

echo "=== 2/3 ECS rolling deploy ==="
TD_ARN=$(aws ecs describe-services --cluster utms-cluster --services utms-smartpresence-api \
  --region $REGION --profile $PROFILE --query 'services[0].taskDefinition' --output text)
aws ecs describe-task-definition --task-definition "$TD_ARN" \
  --region $REGION --profile $PROFILE --query 'taskDefinition' > /tmp/taskdef.json
jq --arg IMAGE "$ECR:$SHA" \
  '(.containerDefinitions[] | select(.name=="utms-smartpresence-api") | .image) |= $IMAGE
   | del(.taskDefinitionArn,.revision,.status,.requiresAttributes,.compatibilities,.registeredAt,.registeredBy)' \
  /tmp/taskdef.json > /tmp/new-taskdef.json
NEW=$(aws ecs register-task-definition --cli-input-json file:///tmp/new-taskdef.json \
  --region $REGION --profile $PROFILE --query 'taskDefinition.[family,revision]' --output text | tr '\t' ':')
echo "Registered $NEW"
grep -o '"FACECHAIN_MODE"[^}]*' /tmp/new-taskdef.json | head -1   # sanity: must say SERVER
aws ecs update-service --cluster utms-cluster --service utms-smartpresence-api \
  --task-definition "$NEW" --region $REGION --profile $PROFILE >/dev/null
echo "Waiting for service stable (rolling, old task keeps serving)..."
aws ecs wait services-stable --cluster utms-cluster --services utms-smartpresence-api \
  --region $REGION --profile $PROFILE
echo "API deployed: $NEW image $ECR:$SHA"

echo "=== 3/3 portal ==="
cd "$HOME/BPR/GitRepos2/BPR1004_uTms/bpr1004.utms.web/bpr.utmsportal/apps/bnet"
grep -lE "utms-api[.-]" dist/assets/index-*.js >/dev/null || { echo "ABORT: bundle missing utms-api-uat"; exit 1; }
aws s3 sync dist/ s3://utms-smartpresence-portal-819144294008/ --delete --profile $PROFILE
aws cloudfront create-invalidation --distribution-id E2VUT3LG51L7V8 --paths "/*" \
  --profile $PROFILE --query 'Invalidation.[Id,Status]' --output text
echo "ALL DONE — portal live after the invalidation completes (~1 min)"
