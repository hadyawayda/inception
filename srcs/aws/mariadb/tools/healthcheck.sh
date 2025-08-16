#!/bin/bash
set -e

ROOT_PASS=$(aws secretsmanager get-secret-value \
    --secret-id inception/db_root_password \
    --query SecretString --output text)

# Exit healthy only if MariaDB responds
mysqladmin ping -u root -p"$ROOT_PASS"
