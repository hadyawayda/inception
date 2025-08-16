#!/bin/bash
set -e

# Fetch all secrets from AWS Secrets Manager
SECRET_JSON=$(aws secretsmanager get-secret-value \
    --secret-id Inception \
    --query SecretString \
    --output text)

ROOT_PASS=$(echo "$SECRET_JSON" | jq -r .db_root_password)

# Exit healthy only if MariaDB responds
mysqladmin ping -u root -p"$ROOT_PASS"
