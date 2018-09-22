#!/bin/bash
set -e

export APP_ENV="${APP_ENV:-development}"
export NODE_ENV=$APP_ENV
export AWS_DEFAULT_REGION=us-west-2

SERVICE_NAME="school-alerter"

if [[ ! -z "$S3_BUCKET" ]]; then
    # Retrieve encrypted config from S3
    aws s3 cp s3://$S3_BUCKET/$APP_ENV/credentials/$SERVICE_NAME/config.json config.encrypt

    # Decrypt
    aws kms decrypt --ciphertext-blob fileb://config.encrypt --query Plaintext --output text | base64 --decode > /opt/app/school-alerter/config.json

    # Cleanup temp file
    rm config.encrypt
fi

LOG_PATH="/var/log/$SERVICE_NAME"

# Create directory structure for log files
mkdir -p $LOG_PATH

APP_LOG_FILENAME="$LOG_PATH/$SERVICE_NAME.log"

# If there is an existing log file, save it (by renaming)
if [ -f "$APP_LOG_FILENAME" ]; then
    # Get the current date/time stamp
    d=$(date '+%y-%m-%d_%H-%M-%S')
    mv $APP_LOG_FILENAME $LOG_PATH/$SERVICE_NAME_$d.log
fi

# Start our Node.js service
cd /opt/app/school-alerter
node app.js --name=$SERVICE_NAME >> $APP_LOG_FILENAME 2>&1
