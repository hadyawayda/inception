#!/bin/bash
set -euo pipefail

WP_PATH=${WP_PATH:-/var/www/html}
DB_PASSWORD_FILE=${MARIADB_PASSWORD_FILE:-/run/secrets/db_password}

# Read password from file first, fallback to env
read_secret() {
  if [ -n "$1" ] && [ -f "$1" ]; then
    cat "$1"
  elif [ -n "${2:-}" ]; then
    echo "$2"
  else
    echo ""
  fi
}

DB_PASS="$(read_secret "$DB_PASSWORD_FILE" "${MARIADB_PASSWORD:-}")"
ADMIN_PASS="${WP_ADMIN_PASSWORD:-}"
USER_PASS="${WP_USER_PASSWORD:-}"

# Defaults for all required vars
: "${MARIADB_USER:=wp_user}"
: "${MARIADB_DATABASE:=wordpress}"
: "${MARIADB_HOST:=mariadb}"
: "${WP_TITLE:=Inception}"
: "${WP_ADMIN_USER:=adminuser}"
: "${WP_ADMIN_EMAIL:=admin@example.com}"
: "${WP_USER:=regularuser}"
: "${WP_USER_EMAIL:=user@example.com}"

# Warn if creds missing but don’t exit immediately
[ -z "$DB_PASS" ] && echo "⚠ Database password is empty"
[ -z "$ADMIN_PASS" ] && echo "⚠ Admin password is empty"
[ -z "$USER_PASS" ] && echo "⚠ User password is empty"

# Download WordPress if not present
if [ ! -f "$WP_PATH/wp-settings.php" ]; then
  echo "📥 Downloading WordPress..."
  curl -fsSL https://wordpress.org/latest.tar.gz | tar -xz --strip-components=1 -C "$WP_PATH"
  chown -R www-data:www-data "$WP_PATH"
fi

# Create wp-config.php if missing
if [ ! -f "$WP_PATH/wp-config.php" ]; then
  echo "⚙ Generating wp-config.php..."
  cp "$WP_PATH/wp-config-sample.php" "$WP_PATH/wp-config.php"
  sed -i "s/database_name_here/${MARIADB_DATABASE}/" "$WP_PATH/wp-config.php"
  sed -i "s/username_here/${MARIADB_USER}/" "$WP_PATH/wp-config.php"
  sed -i "s/password_here/${DB_PASS//\//\\/}/" "$WP_PATH/wp-config.php"
  sed -i "s/localhost/${MARIADB_HOST}/" "$WP_PATH/wp-config.php"
  curl -fsSL https://api.wordpress.org/secret-key/1.1/salt/ >> "$WP_PATH/wp-config.php"
  chown www-data:www-data "$WP_PATH/wp-config.php"
fi

# Wait for MariaDB to be ready
echo "⏳ Waiting for MariaDB at $MARIADB_HOST..."
for i in {1..30}; do
  if mysql -h "$MARIADB_HOST" -u "$MARIADB_USER" -p"$DB_PASS" -e "SELECT 1" &>/dev/null; then
    echo "✅ MariaDB is ready"
    break
  fi
  sleep 1
done

# Install WordPress (skip if already installed)
if ! php -r "include '${WP_PATH}/wp-load.php'; echo (is_blog_installed()?'yes':'no');" | grep -q yes; then
  echo "🚀 Installing WordPress..."
  php -r "
    define('WP_INSTALLING', true);
    require '${WP_PATH}/wp-load.php';
    require '${WP_PATH}/wp-admin/includes/upgrade.php';
    wp_install('${WP_TITLE}', '${WP_ADMIN_USER}', '${WP_ADMIN_EMAIL}', true, '', '${ADMIN_PASS}');
  "
  php -r "
    require '${WP_PATH}/wp-load.php';
    if (!username_exists('${WP_USER}')) {
      wp_create_user('${WP_USER}', '${USER_PASS}', '${WP_USER_EMAIL}');
    }
  "
fi

exec "$@"
