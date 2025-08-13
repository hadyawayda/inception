#!/bin/bash
set -e

PASS_FILE="${MARIADB_ROOT_PASSWORD_FILE:-/run/secrets/db_root_password}"
PASS=""

if [ -n "$PASS_FILE" ] && [ -f "$PASS_FILE" ]; then
    PASS=$(cat "$PASS_FILE")
elif [ -n "$MARIADB_ROOT_PASSWORD" ]; then
    PASS="$MARIADB_ROOT_PASSWORD"
fi

# Exit healthy only if MariaDB responds
mysqladmin ping -h 127.0.0.1 -u root -p"$PASS" --silent || exit 1
