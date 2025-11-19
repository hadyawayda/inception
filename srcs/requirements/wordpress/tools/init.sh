#!/bin/sh
set -e

# If wp-config.php doesn't exist, create it
if [ ! -f /var/www/wordpress/wp-config.php ]; then
  cp /var/www/wordpress/wp-config-sample.php /var/www/wordpress/wp-config.php

  if [ -n "$WP_DB_PASSWORD_FILE" ] && [ -f "$WP_DB_PASSWORD_FILE" ]; then
    WP_DB_PASSWORD=$(cat "$WP_DB_PASSWORD_FILE")
  fi

  sed -i "s/database_name_here/${WP_DB_NAME}/" /var/www/wordpress/wp-config.php
  sed -i "s/username_here/${WP_DB_USER}/" /var/www/wordpress/wp-config.php
  sed -i "s/password_here/${WP_DB_PASSWORD}/" /var/www/wordpress/wp-config.php
  sed -i "s/localhost/${WP_DB_HOST}/" /var/www/wordpress/wp-config.php

  # Optional: set table prefix if provided
  if [ -n "$WP_TABLE_PREFIX" ]; then
    sed -i "s/^\$table_prefix = 'wp_';/\$table_prefix = '${WP_TABLE_PREFIX}';/" /var/www/wordpress/wp-config.php
  fi
fi

# You can add wp-cli here to auto-create admin user if you want.

exec "$@"
