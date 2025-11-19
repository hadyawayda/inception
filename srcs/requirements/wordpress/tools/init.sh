#!/bin/sh
set -e

# Read database password from secret file
if [ -n "${WP_DB_PASSWORD_FILE:-}" ] && [ -f "$WP_DB_PASSWORD_FILE" ]; then
  DB_PASS="$(cat "$WP_DB_PASSWORD_FILE")"
else
  DB_PASS="${WP_DB_PASSWORD:-}"
fi

echo "[WP-ENTRYPOINT] Waiting for MariaDB..."
MAX_TRIES=30
TRIES=0
until nc -z mariadb 3306; do
  TRIES=$((TRIES+1))
  if [ "$TRIES" -ge "$MAX_TRIES" ]; then
    echo "[ERROR] MariaDB not ready after $MAX_TRIES attempts. Exiting."
    exit 1
  fi
  echo "[WARNING] MariaDB not ready yet... retrying ($TRIES/$MAX_TRIES)"
  sleep 2
done
echo "[SUCCESS] MariaDB is up and reachable."

# Download WordPress core if missing
if [ ! -f /var/www/html/wp-settings.php ]; then
    echo "[WP-ENTRYPOINT] Downloading WordPress core..."
    wp core download --path=/var/www/html --allow-root
    echo "[SUCCESS] WordPress core downloaded."
else
    echo "[WARNING] WordPress core already present, skipping download."
fi

# Create wp-config.php if it doesn't exist
if [ ! -f /var/www/html/wp-config.php ]; then
    echo "[WP-ENTRYPOINT] Creating wp-config.php..."
    wp config create \
      --path=/var/www/html \
      --dbname="${WP_DB_NAME}" \
      --dbuser="${WP_DB_USER}" \
      --dbpass="${DB_PASS}" \
      --dbhost=mariadb \
      --skip-check \
      --allow-root
    
    wp config set FS_METHOD direct --path=/var/www/html --allow-root
    wp config set FORCE_SSL_ADMIN true --raw --path=/var/www/html --allow-root
    echo "[SUCCESS] wp-config.php created."
else
    echo "[WARNING] wp-config.php already exists, skipping creation."
fi

# Install WordPress if not already installed
if ! wp core is-installed --path=/var/www/html --allow-root 2>/dev/null; then
    echo "[WP-ENTRYPOINT] Installing WordPress..."
    wp core install \
      --path=/var/www/html \
      --url="${WP_URL}" \
      --title="${WP_TITLE}" \
      --admin_user="${WP_ADMIN_USER}" \
      --admin_password="${WP_ADMIN_PASSWORD}" \
      --admin_email="${WP_ADMIN_EMAIL}" \
      --skip-email \
      --allow-root
    echo "[SUCCESS] WordPress installed."
else
    echo "[WARNING] WordPress already installed, skipping install."
fi

# Update site URLs to match current domain
echo "[WP-ENTRYPOINT] Updating WordPress site URLs..."
wp option update home "${WP_URL}" --path=/var/www/html --allow-root
wp option update siteurl "${WP_URL}" --path=/var/www/html --allow-root
echo "[SUCCESS] Site URLs updated."

# Install and activate wp-force-login plugin
echo "[WP-ENTRYPOINT] Installing wp-force-login plugin..."
if ! wp plugin is-installed wp-force-login --path=/var/www/html --allow-root 2>/dev/null; then
    wp plugin install wp-force-login --path=/var/www/html --allow-root
fi

if ! wp plugin is-active wp-force-login --path=/var/www/html --allow-root 2>/dev/null; then
    wp plugin activate wp-force-login --path=/var/www/html --allow-root
    echo "[SUCCESS] wp-force-login plugin activated."
fi

echo "[WP-ENTRYPOINT] Startup complete. Launching PHP-FPM..."
exec "$@"
