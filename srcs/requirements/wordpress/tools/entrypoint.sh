#!/bin/bash
set -euo pipefail

# ===== Required env (no defaults) ============================================
req() { : "${!1:?Environment variable $1 is required}"; }
req WP_PATH
req MARIADB_HOST
req MARIADB_DATABASE
req MARIADB_USER
req DOMAIN_NAME
req WP_TITLE
req WP_ADMIN_USER
req WP_ADMIN_EMAIL
req WP_ADMIN_PASSWORD
req WP_USER
req WP_USER_EMAIL
req WP_USER_PASSWORD

# DB password must come from file OR env (no default)
if [ -n "${MARIADB_PASSWORD_FILE:-}" ] && [ -f "$MARIADB_PASSWORD_FILE" ]; then
  DB_PASS="$(cat "$MARIADB_PASSWORD_FILE")"
else
  : "${MARIADB_PASSWORD:?Set MARIADB_PASSWORD or MARIADB_PASSWORD_FILE}"
  DB_PASS="$MARIADB_PASSWORD"
fi

# ===== Prep ==================================================================
chown -R www-data:www-data "$WP_PATH"

# Download core if missing (cleaner than curl+tar)
wp core download --path="$WP_PATH" --allow-root

# Create config if missing
wp config create --path="$WP_PATH" --dbname="$MARIADB_DATABASE" --dbuser="$MARIADB_USER" --dbpass="$DB_PASS" --dbhost="$MARIADB_HOST" --skip-check --allow-root

# Generate unique salts and a couple of sane constants
wp config shuffle-salts --path="$WP_PATH" --allow-root
wp config set FS_METHOD direct --path="$WP_PATH" --allow-root
wp config set FORCE_SSL_ADMIN true --raw --path="$WP_PATH" --allow-root

# Install WP on first run
wp core install --path="$WP_PATH" --url="https://${DOMAIN_NAME}" --title="$WP_TITLE" --admin_user="$WP_ADMIN_USER" --admin_password="$WP_ADMIN_PASSWORD" --admin_email="$WP_ADMIN_EMAIL" --skip-email --allow-root

wp user create "$WP_USER" "$WP_USER_EMAIL" --user_pass="$WP_USER_PASSWORD" --role=author --path="$WP_PATH" --allow-root

# Correct, safe perms (no 777)
find "$WP_PATH" -type d -exec chmod 755 {} \;
find "$WP_PATH" -type f -exec chmod 644 {} \;

# Run PHP-FPM in foreground
exec php-fpm -F
