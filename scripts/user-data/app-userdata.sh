#!/bin/bash
set -e

BUCKET="artifact-storage-20260407222333196000000001"
VERSION="edb565f"

yum update -y

# app dir in ec2-user home
mkdir -p /home/ec2-user/app
cd /home/ec2-user/app

# download binary
aws s3 cp s3://$BUCKET/app/$VERSION/app ./app
chmod +x ./app

# install service
curl -o /etc/systemd/system/go-api.service \
  https://raw.githubusercontent.com/aaron-dm-mcdonald/multi-env-ci-demo/main/app/go-api.service

# start service
systemctl daemon-reload
systemctl enable go-api
systemctl start go-api