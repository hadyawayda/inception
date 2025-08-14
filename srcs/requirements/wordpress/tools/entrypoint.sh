#!/bin/bash
set -euo pipefail

# Ensure sbin paths are present so php-fpm8.4 is discoverable
export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:${PATH:-}"

WP_PATH="${WP_PATH:-/var/www/html}"

# --- secrets / env ------------------------------------------------------------
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

if [ -z "${DOMAIN_NAME:-}" ] && [ -n "${LOGIN:-}" ]; then
  DOMAIN_NAME="${LOGIN}.42.fr"
fi

if echo "$WP_ADMIN_USER" | grep -Ei '(^|.*)(admin|administrator)(.*|$)' >/dev/null; then
  echo "❌ WP_ADMIN_USER ('${WP_ADMIN_USER}') must not contain 'admin'/'administrator'." >&2
  exit 1
fi

# --- resolve php-fpm binary (8.4 included) -----------------------------------
FPM_BIN=""
for cand in \
  "$(command -v php-fpm 2>/dev/null || true)" \
  "$(command -v php-fpm8.4 2>/dev/null || true)" \
  "$(command -v php-fpm8.3 2>/dev/null || true)" \
  "$(command -v php-fpm8.2 2>/dev/null || true)" \
  /usr/sbin/php-fpm /usr/sbin/php-fpm8.4 /usr/sbin/php-fpm8.3 /usr/sbin/php-fpm8.2; do
  if [ -n "${cand}" ] && [ -x "${cand}" ]; then FPM_BIN="${cand}"; break; fi
done
if [ -z "$FPM_BIN" ]; then
  echo "❌ php-fpm binary not found. Aborting."
  exit 1
fi

# --- filesystem prep ----------------------------------------------------------
chown -R www-data:www-data "$WP_PATH"

# --- WordPress core -----------------------------------------------------------
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

  # Replace the sample salts block once (avoid duplicates across restarts)
  awk '
    BEGIN {s=0}
    /AUTH_KEY/ && s==0 { s=1; system("curl -fsSL https://api.wordpress.org/secret-key/1.1/salt/"); next }
    s==1 && /NONCE_SALT/ { s=2; next }
    s==1 { next }
    { print }
  ' "$WP_PATH/wp-config.php" > "$WP_PATH/wp-config.php.new" && mv "$WP_PATH/wp-config.php.new" "$WP_PATH/wp-config.php"

  # Set URLs to avoid HTTP_HOST warnings in CLI install
  {
    echo "define('WP_HOME','https://${DOMAIN_NAME}');"
    echo "define('WP_SITEURL','https://${DOMAIN_NAME}');"
    echo "define('FS_METHOD','direct');"
    echo "define('FORCE_SSL_ADMIN', true);"
  } >> "$WP_PATH/wp-config.php"
fi

chown www-data:www-data "$WP_PATH/wp-config.php"

# --- wait for MariaDB ---------------------------------------------------------
echo "⏳ Waiting for MariaDB at $MARIADB_HOST..."
for i in {1..30}; do
  if mysql -h "$MARIADB_HOST" -u "$MARIADB_USER" -p"$DB_PASS" -e "SELECT 1" &>/dev/null; then
    echo "✅ MariaDB is ready"; break
  fi
  sleep 1
done

# --- install WP once ----------------------------------------------------------
if ! php -r "include '${WP_PATH}/wp-load.php'; echo (is_blog_installed()?'yes':'no');" | grep -q yes; then
  echo "🚀 Installing WordPress..."
  php -r "\$_SERVER['HTTP_HOST']='${DOMAIN_NAME}'; define('WP_INSTALLING', true); require '${WP_PATH}/wp-load.php'; require '${WP_PATH}/wp-admin/includes/upgrade.php'; wp_install('${WP_TITLE}','${WP_ADMIN_USER}','${WP_ADMIN_EMAIL}', true, '', '${WP_ADMIN_PASSWORD}');"
  php -r "require '${WP_PATH}/wp-load.php'; if (!username_exists('${WP_USER}')) { wp_create_user('${WP_USER}', '${WP_USER_PASSWORD}', '${WP_USER_EMAIL}'); }"
fi

# --- run php-fpm as PID 1 -----------------------------------------------------
exec "$FPM_BIN" -F
