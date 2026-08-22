#!/bin/bash
# One-shot DB fixes via ECS exec (DB is VPC-private):
#  1. staff 5/6 (C Krishna Mohan, Ajay Kumar): set COMPANY_ID=1 (API maps it insertable=false, dropped it)
#  2. companies: keep only IIM (1) + GBS (19); soft-delete the sample companies (STATUS_ID=2)
# Then verify with selects.
set -u
REGION=eu-central-1; PROFILE=itp; CLUSTER=utms-cluster; SERVICE=utms-smartpresence-api
TASK=$(aws ecs list-tasks --cluster $CLUSTER --service-name $SERVICE --desired-status RUNNING \
  --region $REGION --profile $PROFILE --query 'taskArns[0]' --output text)
echo "Task: $TASK"
REMOTE='
# Stale gallery identity from a pre-wipe enrolment (student 11 no longer exists):
rm -f /var/lib/smartpresence/uploads/gallery/11_00* 2>/dev/null
ls -la /var/lib/smartpresence/uploads/gallery/ | head -30
command -v mysql >/dev/null 2>&1 || { apt-get update -qq >/dev/null 2>&1; apt-get install -y -qq default-mysql-client-core >/dev/null 2>&1; }
HOST=$(echo "$SPRING_DATASOURCE_URL" | sed -E "s#.*//([^:/]+).*#\1#")
export MYSQL_PWD="$SPRING_DATASOURCE_PASSWORD"
mysql --ssl-mode=REQUIRED -h "$HOST" -u "$SPRING_DATASOURCE_USERNAME" -D bnet_remote -t --force -e "
UPDATE staff SET COMPANY_ID=1 WHERE ID IN (5,6);
UPDATE company SET STATUS_ID=2 WHERE ID IN (2,13,14,15,16,17,18);
SELECT ID, FIRST_NAME, LAST_NAME, COMPANY_ID, DEPARTMENT_ID, STATUS_ID FROM staff;
SELECT * FROM faculty;
SELECT ID, NAME, STATUS_ID FROM company;
"
'
B64=$(printf '%s' "$REMOTE" | base64 | tr -d '\n')
aws ecs execute-command --cluster $CLUSTER --task "$TASK" --interactive \
  --command "/bin/sh -c 'echo $B64 | base64 -d | /bin/sh'" \
  --region $REGION --profile $PROFILE
