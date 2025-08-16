#!/bin/bash
set -e

ROOT_PASS=$(aws secretsmanager get-secret-value \
    --secret-id "$DB_ROOT_SECRET_ID" \
    --query SecretString --output text)

# Exit healthy only if MariaDB responds
mysqladmin ping -u root -p"$ROOT_PASS"
