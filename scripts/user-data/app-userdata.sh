#!/bin/bash

BUCKET="artifact-storage-20260407222333196000000001"
VERSION="edb565f"

yum update -y

# app dir
mkdir -p /app
cd /app

# download binary
aws s3 cp s3://$BUCKET/app/$VERSION/app ./app
chmod +x ./app

# install service file from repo
curl -o /etc/systemd/system/go-api.service \
  https://raw.githubusercontent.com/aaron-dm-mcdonald/multi-env-ci-demo/main/app/go-api.service

# start service
systemctl daemon-reload
systemctl enable go-api
systemctl start go-api