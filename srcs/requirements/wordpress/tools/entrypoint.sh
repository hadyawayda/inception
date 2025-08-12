#!/bin/bash
set -euo pipefail

WP_PATH=${WP_PATH:-/var/www/html}

# File path for DB password (keep file-first, then env)
DB_PASSWORD_FILE=${MARIADB_PASSWORD_FILE:-/run/secrets/db_password}

# Non-secret envs (must be present)
: "${MARIADB_HOST:?set in .env}"
: "${MARIADB_DATABASE:?set in .env}"
: "${MARIADB_USER:?set in .env}"
: "${DOMAIN_NAME:?set in .env}"
: "${WP_TITLE:?set in .env}"
: "${WP_ADMIN_USER:?set in .env (must NOT contain admin/Admin/administrator)}"
: "${WP_ADMIN_EMAIL:?set in .env}"
: "${WP_USER:?set in .env}"
: "${WP_USER_EMAIL:?set in .env}"

# Read DB password with file-first fallback to env var
read_secret_or_env() {
  local file="$1"
  local envval="${2:-}"
  if [ -n "${file}" ] && [ -f "${file}" ]; then
    cat "${file}"
  elif [ -n "${envval}" ]; then
    printf "%s" "${envval}"
  else
    printf ""
  fi
}

DB_PASS="$(read_secret_or_env "${DB_PASSWORD_FILE}" "${MARIADB_PASSWORD:-}")"

# Admin/User passwords: **ENV ONLY** from .env
ADMIN_PASS="${WP_ADMIN_PASSWORD:-}"
USER_PASS="${WP_USER_PASSWORD:-}"

# Basic sanity checks
if [ -z "$DB_PASS" ]; then
  echo "Warning: Database password is empty. Provide MARIADB_PASSWORD_FILE or MARIADB_PASSWORD."
fi
if [ -z "$ADMIN_PASS" ]; then
  echo "Warning: Admin password is empty. Set WP_ADMIN_PASSWORD in .env."
fi
if [ -z "$USER_PASS" ]; then
  echo "Warning: User password is empty. Set WP_USER_PASSWORD in .env."
fi

# Download WordPress if missing
if [ ! -f "$WP_PATH/wp-settings.php" ]; then
  echo "Downloading WordPress..."
  curl -fsSL https://wordpress.org/latest.tar.gz | tar -xz --strip-components=1 -C "$WP_PATH"
  chown -R www-data:www-data "$WP_PATH"
fi

# Configure wp-config.php if missing
if [ ! -f "$WP_PATH/wp-config.php" ]; then
  echo "Generating wp-config.php..."
  cp "$WP_PATH/wp-config-sample.php" "$WP_PATH/wp-config.php"
  sed -ri "s/database_name_here/${MARIADB_DATABASE}/" "$WP_PATH/wp-config.php"
  sed -ri "s/username_here/${MARIADB_USER}/" "$WP_PATH/wp-config.php"
  sed -ri "s/password_here/${DB_PASS//\//\\/}/" "$WP_PATH/wp-config.php"
  sed -ri "s/localhost/${MARIADB_HOST}/" "$WP_PATH/wp-config.php"

  # salts (best effort)
  if SALTS="$(curl -fsSL https://api.wordpress.org/secret-key/1.1/salt/)"; then
    awk -v r="$SALTS" '
      /AUTH_KEY|SECURE_AUTH_KEY|LOGGED_IN_KEY|NONCE_KEY|AUTH_SALT|SECURE_AUTH_SALT|LOGGED_IN_SALT|NONCE_SALT/ {print r; skip=8; next}
      skip>0 {skip--; next}
      {print}
    ' "$WP_PATH/wp-config.php" > "$WP_PATH/wp-config.php.tmp" && mv "$WP_PATH/wp-config.php.tmp" "$WP_PATH/wp-config.php"
  fi
  chown www-data:www-data "$WP_PATH/wp-config.php"
fi

# Wait for DB (best effort)
echo "Waiting for MariaDB..."
for i in {1..30}; do
  if mysql -h "$MARIADB_HOST" -u "$MARIADB_USER" -p"$DB_PASS" -e "SELECT 1" >/dev/null 2>&1; then
    break
  fi
  sleep 1
done

# Install WP (idempotent)
if ! php -r "include '${WP_PATH}/wp-load.php'; echo is_blog_installed() ? 'yes' : 'no';" | grep -q yes; then
  echo "Installing WordPress..."
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
