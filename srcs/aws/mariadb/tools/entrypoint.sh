#!/bin/bash

mariadb-upgrade
chown -R mysql:mysql /var/lib/mariadb

mariadbd-safe &
sleep 10

# === Fetch secrets from AWS Secrets Manager ===
ROOT_PASS=$(aws secretsmanager get-secret-value \
    --secret-id inception/db_root_password \
    --query SecretString --output text)

DB_PASS=$(aws secretsmanager get-secret-value \
    --secret-id inception/db_password \
    --query SecretString --output text)

# Set root password
mysql -u "$MARIAD_ROOT_USER" -e "ALTER USER '${MARIAD_ROOT_USER}'@'localhost' IDENTIFIED BY '${ROOT_PASS}';"
mysql -u "$MARIAD_ROOT_USER" -p"${ROOT_PASS}" -e "GRANT ALL PRIVILEGES ON *.* TO '${MARIAD_ROOT_USER}'@'localhost' IDENTIFIED BY '${ROOT_PASS}' WITH GRANT OPTION; FLUSH PRIVILEGES;"

# Create database and user for WordPress
mysql -u "$MARIAD_ROOT_USER" -p"${ROOT_PASS}" -e "CREATE DATABASE IF NOT EXISTS ${MARIADB_DATABASE} CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
mysql -u "$MARIAD_ROOT_USER" -p"${ROOT_PASS}" -e "CREATE USER IF NOT EXISTS '${MARIADB_USER}'@'%' IDENTIFIED BY '${DB_PASS}';"
mysql -u "$MARIAD_ROOT_USER" -p"${ROOT_PASS}" -e "GRANT ALL PRIVILEGES ON ${MARIADB_DATABASE}.* TO '${MARIADB_USER}'@'%'; FLUSH PRIVILEGES;"

mysqladmin -u "$MARIAD_ROOT_USER" -p"${ROOT_PASS}" shutdown
sleep 5

# Run MariaDB
exec mysqld
