#!/bin/bash
ENV=$1
VERSION=$2
BUCKET=$3

INSTANCE_ID=$(aws ec2 describe-instances \
  --filters "Name=tag:env,Values=$ENV" "Name=instance-state-name,Values=running" \
  --query 'Reservations[0].Instances[0].InstanceId' \
  --output text)

aws ssm send-command \
  --instance-ids "$INSTANCE_ID" \
  --document-name "AWS-RunShellScript" \
  --parameters "commands=[
    'aws s3 cp s3://$BUCKET/app/$VERSION/app /home/ec2-user/app/app',
    'chmod +x /home/ec2-user/app/app',
    'sudo systemctl restart go-api'
  ]"