#!/bin/bash
set -euo pipefail

# ===== Colors =====
RED="\033[1;31m"
GREEN="\033[1;32m"
YELLOW="\033[1;33m"
BLUE="\033[1;34m"
MAGENTA="\033[1;35m"
CYAN="\033[1;36m"
RESET="\033[0m"

log() {
  echo -e "${CYAN}[WP-ENTRYPOINT]${RESET} $1"
}
success() {
  echo -e "${GREEN}[SUCCESS]${RESET} $1"
}
warn() {
  echo -e "${YELLOW}[WARNING]${RESET} $1"
}
error() {
  echo -e "${RED}[ERROR]${RESET} $1"
}

# ===== Required env (no defaults) ============================================
log "Checking required environment variables..."
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
success "All required environment variables are set."

# DB password must come from file OR env (no default)
if [ -n "${MARIADB_PASSWORD_FILE:-}" ] && [ -f "$MARIADB_PASSWORD_FILE" ]; then
  log "Reading DB password from file: $MARIADB_PASSWORD_FILE"
  DB_PASS="$(cat "$MARIADB_PASSWORD_FILE")"
else
  : "${MARIADB_PASSWORD:?Set MARIADB_PASSWORD or MARIADB_PASSWORD_FILE}"
  DB_PASS="$MARIADB_PASSWORD"
  log "Using DB password from environment variable."
fi

# ===== Prep ==================================================================
log "Ensuring correct ownership of $WP_PATH..."
chown -R www-data:www-data "$WP_PATH"

# Download core if missing
if [ ! -f "$WP_PATH/wp-settings.php" ]; then
    log "Downloading WordPress core..."
    wp core download --path="$WP_PATH" --allow-root
    success "WordPress core downloaded."
else
    warn "WordPress core already present, skipping download."
fi

log "Waiting 20 seconds to ensure DB is ready..."
sleep 20

# Only create wp-config.php if it doesn't exist
if [ ! -f "$WP_PATH/wp-config.php" ]; then
    log "Creating wp-config.php..."
    wp config create --path="$WP_PATH" --dbname="$MARIADB_DATABASE" --dbuser="$MARIADB_USER" --dbpass="$DB_PASS" --dbhost="$MARIADB_HOST" --skip-check --allow-root
    wp config shuffle-salts --path="$WP_PATH" --allow-root
    wp config set FS_METHOD direct --path="$WP_PATH" --allow-root
    wp config set FORCE_SSL_ADMIN true --raw --path="$WP_PATH" --allow-root
    success "wp-config.php created."
else
    warn "wp-config.php already exists, skipping creation."
fi

# Install WP on first run
if ! wp core is-installed --path="$WP_PATH" --allow-root; then
    log "Installing WordPress..."
    wp core install --path="$WP_PATH" --url="https://${DOMAIN_NAME}" --title="$WP_TITLE" --admin_user="$WP_ADMIN_USER" --admin_password="$WP_ADMIN_PASSWORD" --admin_email="$WP_ADMIN_EMAIL" --skip-email --allow-root
    success "WordPress installed."
else
    warn "WordPress already installed, skipping install."
fi

# Create additional user
log "Ensuring author user exists..."
wp user get "$WP_USER" --path="$WP_PATH" --allow-root >/dev/null 2>&1 || wp user create "$WP_USER" "$WP_USER_EMAIL" --user_pass="$WP_USER_PASSWORD" --role=author --path="$WP_PATH" --allow-root
success "Author user checked/created."

# Correct, safe perms
log "Setting directory and file permissions..."
find "$WP_PATH" -type d -exec chmod 755 {} \;
find "$WP_PATH" -type f -exec chmod 644 {} \;
success "Permissions updated."

log "Startup complete. Launching PHP-FPM..."
exec php-fpm -F
