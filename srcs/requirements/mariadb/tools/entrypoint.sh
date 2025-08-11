#!/bin/sh
set -eu

# Read secrets (preferred) or env fallbacks
if [ -f "${MARIADB_ROOT_PASSWORD_FILE:-}" ]; then
  MARIADB_ROOT_PASSWORD="$(cat "$MARIADB_ROOT_PASSWORD_FILE")"
fi
if [ -z "${MARIADB_ROOT_PASSWORD:-}" ]; then
  echo "ERROR: MARIADB_ROOT_PASSWORD not set (use secrets or env)"; exit 1
fi
if [ -f "${MARIADB_PASSWORD_FILE:-}" ]; then
  MARIADB_PASSWORD="$(cat "$MARIADB_PASSWORD_FILE")"
fi
if [ -z "${MARIADB_PASSWORD:-}" ]; then
  echo "ERROR: MARIADB_PASSWORD not set (use secrets or env)"; exit 1
fi

: "${MARIADB_DATABASE:=wordpress}"
: "${MARIADB_USER:=wp_user}"

# Directories
mkdir -p /run/mysqld
chown -R mysql:mysql /run/mysqld /var/lib/mysql

# Initialize if needed
if [ ! -d /var/lib/mysql/mysql ]; then
  echo "[entrypoint] Initializing database..."
  mariadb-install-db --user=mysql --datadir=/var/lib/mysql --skip-test-db --auth-root-authentication-method=normal

  # Start temporary server (socket only)
  mysqld --user=mysql --datadir=/var/lib/mysql --skip-networking --socket=/run/mysqld/mysqld.sock &
  tmp_pid="$!"

  # Wait until ready
  for i in 1 2 3 4 5 6 7 8 9 10; do
    if mysqladmin --protocol=socket --socket=/run/mysqld/mysqld.sock ping >/dev/null 2>&1; then
      break
    fi
    sleep 1
  done

  # Secure + create DB/user
  cat >/tmp/init.sql <<-SQL
    ALTER USER 'root'@'localhost' IDENTIFIED BY '${MARIADB_ROOT_PASSWORD}';
    DELETE FROM mysql.user WHERE User='' OR (User='root' AND Host NOT IN ('localhost'));
    DROP DATABASE IF EXISTS test;
    DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';

    CREATE DATABASE IF NOT EXISTS \`${MARIADB_DATABASE}\` CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci;
    CREATE USER IF NOT EXISTS '${MARIADB_USER}'@'%' IDENTIFIED BY '${MARIADB_PASSWORD}';
    GRANT ALL PRIVILEGES ON \`${MARIADB_DATABASE}\`.* TO '${MARIADB_USER}'@'%';
    FLUSH PRIVILEGES;
SQL

  mysql --protocol=socket --socket=/run/mysqld/mysqld.sock -uroot < /tmp/init.sql
  rm -f /tmp/init.sql

  # Shutdown temp server gracefully (now requires root password)
  if ! mysqladmin --protocol=socket --socket=/run/mysqld/mysqld.sock -uroot -p"${MARIADB_ROOT_PASSWORD}" shutdown; then
    kill "$tmp_pid" 2>/dev/null || true
    wait "$tmp_pid" 2>/dev/null || true
  fi
fi

echo "[entrypoint] Starting MariaDB..."
exec mysqld --user=mysql --datadir=/var/lib/mysql --bind-address=0.0.0.0
