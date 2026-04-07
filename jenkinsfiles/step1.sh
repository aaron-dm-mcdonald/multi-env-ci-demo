#!/bin/bash
ENV=$1
VERSION=$2
BUCKET=$3

INSTANCE_ID=$(aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=dev-app" "Name=instance-state-name,Values=running" \
  --query 'Reservations[0].Instances[0].InstanceId' \
  --output text)

aws ec2-instance-connect ssh \
  --instance-id "$INSTANCE_ID" \
  --os-user ec2-user \
  --command "
    aws s3 cp s3://$BUCKET/app/$VERSION/app /home/ec2-user/app/app &&
    chmod +x /home/ec2-user/app/app &&
    sudo systemctl restart go-api
  "