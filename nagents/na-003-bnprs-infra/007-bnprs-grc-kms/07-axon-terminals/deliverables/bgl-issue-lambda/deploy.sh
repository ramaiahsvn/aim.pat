#!/usr/bin/env bash
# bgl-issue — provisioning runbook (na-003/007 grc-kms).
# !!! DO NOT RUN until the owner approves AWS provisioning. Each step is a real,
# billable, production write in bnprs (891963159778) / ap-south-2. Reuses the live
# k3-verifychallenge stack (API GW 8nlf3cfyd9, kms.bnprs.ai, mTLS truststore, WAF).
set -euo pipefail
PROFILE=bnprs REGION=ap-south-2
echo "REVIEW ME — this script is intentionally inert."; exit 1   # remove after approval

# 1) KMS CMK to envelope-encrypt the signing secret
aws kms create-key --description "BGL Ed25519 signing key envelope (kid=3)" \
    --profile $PROFILE --region $REGION   # → note KeyId
aws kms create-alias --alias-name alias/bnprs-bgl-signing-prod \
    --target-key-id <KeyId> --profile $PROFILE --region $REGION
aws kms enable-key-rotation --key-id <KeyId> --profile $PROFILE --region $REGION

# 2) Migrate kid=3 secret → Secrets Manager (generate→store→wipe). Decrypt the custodied
#    blob locally, store the 64B binary secret, then shred the plaintext.
PASS=$(security find-generic-password -s bgl-kid3-signing-key -w)
openssl enc -d -aes-256-cbc -pbkdf2 -iter 200000 \
    -in ~/BPR/.keys-backup/bgl/bgl-kid3.key.enc -out /tmp/bgl-kid3.key -pass pass:"$PASS"; unset PASS
aws secretsmanager create-secret --name bgl-signing-key \
    --kms-key-id alias/bnprs-bgl-signing-prod \
    --secret-binary fileb:///tmp/bgl-kid3.key --profile $PROFILE --region $REGION
shred -u /tmp/bgl-kid3.key

# 3) Issuance log (revocation source of truth for perpetual tokens)
aws dynamodb create-table --table-name bgl-issuance-log \
    --attribute-definitions AttributeName=lid,AttributeType=S \
    --key-schema AttributeName=lid,KeyType=HASH --billing-mode PAY_PER_REQUEST \
    --profile $PROFILE --region $REGION

# 4) Build + deploy the Lambda (arm64, like k3). IAM role needs secretsmanager:GetSecretValue
#    on bgl-signing-key, kms:Decrypt on the CMK, dynamodb:PutItem on bgl-issuance-log.
cargo lambda build --release --arm64
cargo lambda deploy bgl-issue --profile $PROFILE --region $REGION \
    --iam-role arn:aws:iam::891963159778:role/bgl-issue-lambda

# 5) Add the route to the EXISTING API GW (reuses kms.bnprs.ai domain, mTLS, WAF)
APIID=8nlf3cfyd9
INTEG=$(aws apigatewayv2 create-integration --api-id $APIID --integration-type AWS_PROXY \
    --integration-uri arn:aws:lambda:$REGION:891963159778:function:bgl-issue \
    --payload-format-version 2.0 --profile $PROFILE --region $REGION --query IntegrationId --output text)
aws apigatewayv2 create-route --api-id $APIID --route-key 'POST /bgl/v1/issue' \
    --target "integrations/$INTEG" --profile $PROFILE --region $REGION
aws lambda add-permission --function-name bgl-issue --statement-id apigw-bgl \
    --action lambda:InvokeFunction --principal apigateway.amazonaws.com \
    --source-arn "arn:aws:execute-api:$REGION:891963159778:$APIID/*/POST/bgl/v1/issue" \
    --profile $PROFILE --region $REGION

# 6) Record resulting ARNs in 08-memory/long-term/key-registry.yaml. Smoke test:
#    real workstation bgl-enroll.exe → token → bgl-inspect VALID → activates BprCardQi.
