#!/bin/bash
# Move the UAT API onto the bnprs.in standard: utms-api.uat.bnprs.in → utms-shared-alb.
#  1. DNS-validate the new *.uat.bnprs.in ACM cert (eu-central-1, already requested)
#  2. Attach it to the ALB's :8043 and :8053 listeners (SNI — itpgateway keeps working)
#  3. A-alias utms-api.uat.bnprs.in → the ALB
#  4. Verify TLS + API on the new name
set -euo pipefail
ITP="--region eu-central-1 --profile itp"
ZONE=Z04234212M3SJ07Y70SGQ            # bnprs.in (profile bnprs)
CERT=arn:aws:acm:eu-central-1:819144294008:certificate/2fb7274e-7732-47ef-9833-1877b8d4e22f
ALB_ARN=arn:aws:elasticloadbalancing:eu-central-1:819144294008:loadbalancer/app/utms-shared-alb/b50977b956df1df6
ALB_DNS=utms-shared-alb-112281594.eu-central-1.elb.amazonaws.com
ALB_ZONE=Z215JYRZR1TBD5
SCRATCH="$(dirname "$0")"

echo "=== 1/4 ACM validation CNAME"
aws route53 change-resource-record-sets --hosted-zone-id $ZONE \
  --change-batch "file://$SCRATCH/acm-validate.json" --profile bnprs \
  --query 'ChangeInfo.Status' --output text
echo "waiting for certificate ISSUED (usually 1-3 min)..."
aws acm wait certificate-validated --certificate-arn $CERT $ITP
echo "certificate ISSUED"

echo "=== 2/4 attach cert to ALB listeners :8043 + :8053"
for L in $(aws elbv2 describe-listeners --load-balancer-arn $ALB_ARN $ITP \
             --query 'Listeners[?Port==`8043`||Port==`8053`].ListenerArn' --output text); do
  aws elbv2 add-listener-certificates --listener-arn "$L" \
    --certificates CertificateArn=$CERT $ITP >/dev/null
  echo "attached to $L"
done

echo "=== 3/4 A-alias utms-api.uat.bnprs.in -> $ALB_DNS"
cat > /tmp/api-alias.json <<EOF
{"Changes":[{"Action":"UPSERT","ResourceRecordSet":{"Name":"utms-api.uat.bnprs.in.","Type":"A",
"AliasTarget":{"HostedZoneId":"$ALB_ZONE","DNSName":"$ALB_DNS","EvaluateTargetHealth":false}}}]}
EOF
aws route53 change-resource-record-sets --hosted-zone-id $ZONE \
  --change-batch file:///tmp/api-alias.json --profile bnprs \
  --query 'ChangeInfo.Status' --output text

echo "=== 4/4 verify (DNS may need ~1 min)"
sleep 60
curl -s -o /dev/null -w "TLS+API on :8043 -> HTTP %{http_code} (401 = cert good, auth required)\n" \
  "https://utms-api.uat.bnprs.in:8043/bnet/Courses?pageNumber=1&pageSize=1&companyId=1"
echo "ALL DONE - utms-api.uat.bnprs.in is live; itpgateway.com name still works in parallel"
