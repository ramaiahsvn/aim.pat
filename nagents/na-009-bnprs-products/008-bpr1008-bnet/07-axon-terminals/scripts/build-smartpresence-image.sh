#!/bin/bash
# Build + push the smartpresence API image exactly as the CI job would
# (buildx linux/amd64, ECR layer cache, MAVEN_TOKEN from env for the GitLab
# Maven registry). Mirrors .gitlab-ci.yml build-and-push-smartpresence-api.
set -euo pipefail
cd "$HOME/BPR/GitRepos2/BPR1004_uTms/bpr1004.utms.api.bnet.smartpresence"
SHA=$(git rev-parse HEAD)
ECR=819144294008.dkr.ecr.eu-central-1.amazonaws.com/utms-smartpresence-api

docker pull -q "$ECR:latest" || true
# --provenance/--sbom off: BuildKit otherwise pushes an OCI image index with an
# attestation manifest (platform unknown/unknown) that Fargate rejects with
# "image ... does not provide any platform". Plain single-platform manifest only.
docker buildx build \
  --platform linux/amd64 \
  --provenance=false \
  --sbom=false \
  --cache-from "$ECR:latest" \
  --cache-to type=inline \
  --build-arg MAVEN_TOKEN="$GITLAB_PAT" \
  --load \
  -t "$ECR:$SHA" \
  -t "$ECR:latest" \
  -f Dockerfile .

docker push "$ECR:$SHA"
docker push "$ECR:latest"
echo "PUSHED: $ECR:$SHA"
