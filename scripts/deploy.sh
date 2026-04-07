#!/bin/bash

ENV=$1
VERSION=$2

SERVICE=api
BUCKET=my-artifacts

if [ "$ENV" == "dev" ]; then
  INSTANCE_ID=$DEV_INSTANCE_ID
elif [ "$ENV" == "qa" ]; then
  INSTANCE_ID=$QA_INSTANCE_ID
else
  echo "Unknown environment: $ENV"
  exit 1
fi

echo "Deploying version $VERSION to $ENV ($INSTANCE_ID)"

aws ec2-instance-connect ssh \
  --instance-id $INSTANCE_ID \
  --os-user ec2-user \
  --command "
    aws s3 cp s3://$BUCKET/$SERVICE/$VERSION/app /tmp/app
    chmod +x /tmp/app

    sudo systemctl stop $SERVICE
    sudo mv /tmp/app /opt/$SERVICE/app
    sudo systemctl start $SERVICE
  "