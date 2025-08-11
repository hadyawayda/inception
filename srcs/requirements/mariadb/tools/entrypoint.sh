#!/bin/sh
set -eu

# --- read secrets or env ---
if [ -n "${MARIADB_ROOT_PASSWORD_FILE:-}" ] && [ -f "${MARIADB_ROOT_PASSWORD_FILE}" ]; then
  MARIADB_ROOT_PASSWORD="$(cat "$MARIADB_ROOT_PASSWORD_FILE")"
fi
: "${MARIADB_ROOT_PASSWORD:?ERROR: MARIADB_ROOT_PASSWORD not set (use secrets or env)}"

if [ -n "${MARIADB_PASSWORD_FILE:-}" ] && [ -f "${MARIADB_PASSWORD_FILE}" ]; then
  MARIADB_PASSWORD="$(cat "$MARIADB_PASSWORD_FILE")"
fi
: "${MARIADB_PASSWORD:?ERROR: MARIADB_PASSWORD not set (use secrets or env)}"

: "${MARIADB_DATABASE:=wordpress}"
: "${MARIADB_USER:=wp_user}"

# --- dirs/ownership ---
mkdir -p /run/mysqld
chown -R mysql:mysql /run/mysqld /var/lib/mysql

# --- helper to run SQL over local socket as root (no network) ---
run_sql() {
  mysql --protocol=socket --socket=/run/mysqld/mysqld.sock -uroot "$@"
}

# --- first-time init: create system tables ---
if [ ! -d /var/lib/mysql/mysql ]; then
  echo "[entrypoint] Initializing system tables..."
  mariadb-install-db --user=mysql --datadir=/var/lib/mysql --skip-test-db --auth-root-authentication-method=normal
fi

# --- start temp server (socket only) ---
mysqld --user=mysql --datadir=/var/lib/mysql --skip-networking --socket=/run/mysqld/mysqld.sock &
tmp_pid="$!"

# --- wait for server ready ---
for i in $(seq 1 30); do
  if mysqladmin --protocol=socket --socket=/run/mysqld/mysqld.sock ping >/dev/null 2>&1; then
    break
  fi
  sleep 1
done

# --- secure root + baseline hygiene ---
cat >/tmp/bootstrap.sql <<SQL
ALTER USER 'root'@'localhost' IDENTIFIED BY '${MARIADB_ROOT_PASSWORD}';
-- (optional hardening)
DELETE FROM mysql.user WHERE User='' OR (User='root' AND Host NOT IN ('localhost'));
DROP DATABASE IF EXISTS test;
DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';
SQL
run_sql < /tmp/bootstrap.sql
rm -f /tmp/bootstrap.sql

# --- ensure app database + db user (no WP tables here) ---
cat >/tmp/app.sql <<SQL
CREATE DATABASE IF NOT EXISTS \`${MARIADB_DATABASE}\`
  CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci;
CREATE USER IF NOT EXISTS '${MARIADB_USER}'@'%' IDENTIFIED BY '${MARIADB_PASSWORD}';
GRANT ALL PRIVILEGES ON \`${MARIADB_DATABASE}\`.* TO '${MARIADB_USER}'@'%';
FLUSH PRIVILEGES;
SQL
run_sql -p"${MARIADB_ROOT_PASSWORD}" < /tmp/app.sql
rm -f /tmp/app.sql

# --- optional: import any seed SQL dropped into this dir (kept for later steps) ---
if [ -d /docker-entrypoint-initdb.d ]; then
  for f in /docker-entrypoint-initdb.d/*; do
    case "$f" in
      *.sql)     echo "[entrypoint] applying $f"; run_sql -p"${MARIADB_ROOT_PASSWORD}" < "$f" ;;
      *.sql.gz)  echo "[entrypoint] applying $f"; gunzip -c "$f" | run_sql -p"${MARIADB_ROOT_PASSWORD}" ;;
      *.sh)      echo "[entrypoint] running $f"; sh "$f" ;;
      *)         ;;
    esac
  done
fi

# --- stop temp server cleanly, then relaunch with networking ---
if ! mysqladmin --protocol=socket --socket=/run/mysqld/mysqld.sock -uroot -p"${MARIADB_ROOT_PASSWORD}" shutdown; then
  kill "$tmp_pid" 2>/dev/null || true
  wait "$tmp_pid" 2>/dev/null || true
fi

echo "[entrypoint] Starting MariaDB..."
exec mysqld --user=mysql --datadir=/var/lib/mysql --bind-address=0.0.0.0
