#!/bin/bash
set -euo pipefail

# Ensure PATH has sbin so we can find php-fpm8.x
export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:${PATH:-}"

WP_PATH="${WP_PATH:-/var/www/html}"

DB_PASSWORD_FILE="${MARIADB_PASSWORD_FILE:-/run/secrets/db_password}"
read_secret() { local f="${1:-}"; local fb="${2:-}"; if [ -n "$f" ] && [ -f "$f" ]; then cat "$f"; else echo -n "$fb"; fi; }

DB_PASS="$(read_secret "$DB_PASSWORD_FILE" "${MARIADB_PASSWORD:-}")"
: "${MARIADB_USER:=wp_user}"
: "${MARIADB_DATABASE:=wordpress}"
: "${MARIADB_HOST:=mariadb}"

: "${WP_TITLE:=Inception}"
: "${WP_ADMIN_USER:=adminuser}"
: "${WP_ADMIN_EMAIL:=admin@example.com}"
: "${WP_USER:=regularuser}"
: "${WP_USER_EMAIL:=user@example.com}"
: "${WP_ADMIN_PASSWORD:=}"
: "${WP_USER_PASSWORD:=}"
: "${DOMAIN_NAME:=localhost}"

[ -z "$DB_PASS" ] && echo "⚠ Database password is empty"
[ -z "$WP_ADMIN_PASSWORD" ] && echo "⚠ Admin password is empty"

# Resolve the php-fpm binary robustly
FPM_BIN=""
for cand in \
  "$(command -v php-fpm 2>/dev/null || true)" \
  "$(command -v php-fpm8.3 2>/dev/null || true)" \
  "$(command -v php-fpm8.2 2>/dev/null || true)" \
  /usr/sbin/php-fpm /usr/sbin/php-fpm8.3 /usr/sbin/php-fpm8.2; do
  if [ -n "${cand}" ] && [ -x "${cand}" ]; then FPM_BIN="${cand}"; break; fi
done
if [ -z "$FPM_BIN" ]; then
  echo "❌ php-fpm binary not found. Aborting."
  exit 1
fi

chown -R www-data:www-data "$WP_PATH"

# Download WordPress if missing
if [ ! -f "$WP_PATH/wp-settings.php" ]; then
  echo "📥 Downloading WordPress..."
  curl -fsSL https://wordpress.org/latest.tar.gz | tar -xz --strip-components=1 -C "$WP_PATH"
fi

# Create wp-config.php idempotently
if [ ! -f "$WP_PATH/wp-config.php" ]; then
  echo "⚙ Generating wp-config.php..."
  cp "$WP_PATH/wp-config-sample.php" "$WP_PATH/wp-config.php"
  sed -i "s/database_name_here/${MARIADB_DATABASE}/" "$WP_PATH/wp-config.php"
  sed -i "s/username_here/${MARIADB_USER}/" "$WP_PATH/wp-config.php"
  sed -i "s/password_here/${DB_PASS//\//\\/}/" "$WP_PATH/wp-config.php"
  sed -i "s/localhost/${MARIADB_HOST}/" "$WP_PATH/wp-config.php"

  # Replace the sample salt block once (avoid duplicates)
  awk '
    BEGIN {s=0}
    /AUTH_KEY/ && s==0 { s=1; system("curl -fsSL https://api.wordpress.org/secret-key/1.1/salt/"); next }
    s==1 && /NONCE_SALT/ { s=2; next }
    s==1 { next }
    { print }
  ' "$WP_PATH/wp-config.php" > "$WP_PATH/wp-config.php.new" && mv "$WP_PATH/wp-config.php.new" "$WP_PATH/wp-config.php"

  # Site URLs to suppress HTTP_HOST warnings in CLI
  {
    echo "define('WP_HOME','https://${DOMAIN_NAME}');"
    echo "define('WP_SITEURL','https://${DOMAIN_NAME}');"
    echo "define('FS_METHOD','direct');"
    echo "define('FORCE_SSL_ADMIN', true);"
  } >> "$WP_PATH/wp-config.php"
fi

chown www-data:www-data "$WP_PATH/wp-config.php"

# Wait for MariaDB
echo "⏳ Waiting for MariaDB at $MARIADB_HOST..."
for i in {1..30}; do
  if mysql -h "$MARIADB_HOST" -u "$MARIADB_USER" -p"$DB_PASS" -e "SELECT 1" &>/dev/null; then
    echo "✅ MariaDB is ready"; break
  fi
  sleep 1
done

# Install WordPress once
if ! php -r "include '${WP_PATH}/wp-load.php'; echo (is_blog_installed()?'yes':'no');" | grep -q yes; then
  echo "🚀 Installing WordPress..."
  php -r "\$_SERVER['HTTP_HOST']='${DOMAIN_NAME}'; define('WP_INSTALLING', true); require '${WP_PATH}/wp-load.php'; require '${WP_PATH}/wp-admin/includes/upgrade.php'; wp_install('${WP_TITLE}','${WP_ADMIN_USER}','${WP_ADMIN_EMAIL}', true, '', '${WP_ADMIN_PASSWORD}');"
  php -r "require '${WP_PATH}/wp-load.php'; if (!username_exists('${WP_USER}')) { wp_create_user('${WP_USER}', '${WP_USER_PASSWORD}', '${WP_USER_EMAIL}'); }"
fi

# Run php-fpm in foreground as PID 1
exec "$FPM_BIN" -F
