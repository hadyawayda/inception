#!/bin/sh
set -e

# Read secrets from files
if [ -n "$MYSQL_ROOT_PASSWORD_FILE" ] && [ -f "$MYSQL_ROOT_PASSWORD_FILE" ]; then
  MYSQL_ROOT_PASSWORD=$(cat "$MYSQL_ROOT_PASSWORD_FILE")
fi

if [ -n "$MYSQL_PASSWORD_FILE" ] && [ -f "$MYSQL_PASSWORD_FILE" ]; then
  MYSQL_PASSWORD=$(cat "$MYSQL_PASSWORD_FILE")
fi

# Initialize DB directory if empty
if [ ! -d /var/lib/mysql/mysql ]; then
  mysql_install_db --user=mysql --datadir=/var/lib/mysql

  mysqld --user=mysql --skip-networking &
  pid="$!"

  # wait for server
  for i in 30 60 90; do
    if mysqladmin ping --silent; then
      break
    fi
    sleep 1
  done

  # Create DB and user
  mysql -uroot <<-EOSQL
    ALTER USER 'root'@'localhost' IDENTIFIED BY '${MYSQL_ROOT_PASSWORD}';
    CREATE DATABASE IF NOT EXISTS \`${MYSQL_DATABASE}\`;
    CREATE USER IF NOT EXISTS '${MYSQL_USER}'@'%' IDENTIFIED BY '${MYSQL_PASSWORD}';
    GRANT ALL PRIVILEGES ON \`${MYSQL_DATABASE}\`.* TO '${MYSQL_USER}'@'%';
    FLUSH PRIVILEGES;
EOSQL

  mysqladmin -uroot -p"${MYSQL_ROOT_PASSWORD}" shutdown
  wait "$pid"
fi

# Exec mysqld as PID 1
exec "$@"
