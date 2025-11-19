#!/bin/sh
set -e

# Set WP-CLI cache directory
export WP_CLI_CACHE_DIR=/tmp/.wp-cli/cache

# Read database password from secret file
if [ -f "$WP_DB_PASSWORD_FILE" ]; then
  WP_DB_PASSWORD=$(cat "$WP_DB_PASSWORD_FILE")
export WP_DB_PASSWORD
fi

# Download WordPress if not already present
if [ ! -f /var/www/html/wp-settings.php ]; then
  echo "Downloading WordPress..."
  wp core download --path=/var/www/html --allow-root
fi

# Wait for MariaDB to be ready
echo "Waiting for MariaDB to be ready..."
until nc -z mariadb 3306; do
  sleep 1
done
sleep 2

# Create wp-config.php if it doesn't exist
if [ ! -f /var/www/html/wp-config.php ]; then
  echo "Creating wp-config.php..."
  wp config create \
    --dbname="${WP_DB_NAME}" \
    --dbuser="${WP_DB_USER}" \
    --dbpass="${WP_DB_PASSWORD}" \
    --dbhost=mariadb \
    --path=/var/www/html \
    --allow-root
fi

# Install WordPress if not already installed
if ! wp core is-installed --path=/var/www/html --allow-root 2>/dev/null; then
  echo "Installing WordPress..."
  wp core install \
    --url="${WP_URL}" \
    --title="${WP_TITLE}" \
    --admin_user="${WP_ADMIN_USER}" \
    --admin_password="${WP_ADMIN_PASSWORD}" \
    --admin_email="${WP_ADMIN_EMAIL}" \
    --path=/var/www/html \
    --allow-root \
    --skip-email
  
  echo "WordPress installed successfully!"
fi

exec "$@"
