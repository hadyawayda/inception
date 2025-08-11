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

# If your .cnf uses a file error log, uncomment these:
# mkdir -p /var/log/mysql
# chown -R mysql:mysql /var/log/mysql

# convenience: socket root login
SQL_SOCK="--protocol=socket --socket=/run/mysqld/mysqld.sock"
mysql_sock() { mysql $SQL_SOCK -uroot "$@"; }

# Fresh init if system tables are missing (true first boot)
if [ ! -d /var/lib/mysql/mysql ]; then
  echo "[entrypoint] Initializing system tables..."
  mariadb-install-db --user=mysql \
                     --datadir=/var/lib/mysql \
                     --skip-test-db \
                     --auth-root-authentication-method=normal
fi

# start temporary server on socket only
mysqld --user=mysql --datadir=/var/lib/mysql --skip-networking --socket=/run/mysqld/mysqld.sock &
tmp_pid="$!"

# wait ready
for i in $(seq 1 40); do
  if mysqladmin $SQL_SOCK ping >/dev/null 2>&1; then break; fi
  sleep 1
done

# sanity check: ensure mysql.user exists; if not, bail with a helpful msg
if ! mysql_sock -e "SELECT 1 FROM mysql.user LIMIT 1;" >/dev/null 2>&1; then
  echo >&2 "[entrypoint] CRITICAL: mysql system tables are missing/corrupted in /var/lib/mysql."
  echo >&2 "           Remove the contents of your bind path and re-run to initialize cleanly."
  echo >&2 "           Current datadir: /var/lib/mysql (host: ${HOST_DATA_DIR:-unknown}/mariadb)"
  kill "$tmp_pid" 2>/dev/null || true
  wait "$tmp_pid" 2>/dev/null || true
  exit 1
fi

# secure root + create app db/user (idempotent)
mysql_sock <<SQL
ALTER USER 'root'@'localhost' IDENTIFIED BY '${MARIADB_ROOT_PASSWORD}';
CREATE DATABASE IF NOT EXISTS \`${MARIADB_DATABASE}\`
  CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci;
CREATE USER IF NOT EXISTS '${MARIADB_USER}'@'%' IDENTIFIED BY '${MARIADB_PASSWORD}';
GRANT ALL PRIVILEGES ON \`${MARIADB_DATABASE}\`.* TO '${MARIADB_USER}'@'%';
FLUSH PRIVILEGES;
SQL

# optional seeds in /docker-entrypoint-initdb.d
if [ -d /docker-entrypoint-initdb.d ]; then
  for f in /docker-entrypoint-initdb.d/*; do
    case "$f" in
      *.sql)    echo "[entrypoint] applying $f"; mysql_sock -p"${MARIADB_ROOT_PASSWORD}" < "$f" ;;
      *.sql.gz) echo "[entrypoint] applying $f"; gunzip -c "$f" | mysql_sock -p"${MARIADB_ROOT_PASSWORD}" ;;
      *.sh)     echo "[entrypoint] running  $f"; sh "$f" ;;
      *)        ;;
    esac
  done
fi

# stop temp server and relaunch with networking
if ! mysqladmin $SQL_SOCK -uroot -p"${MARIADB_ROOT_PASSWORD}" shutdown; then
  kill "$tmp_pid" 2>/dev/null || true
  wait "$tmp_pid" 2>/dev/null || true
fi

echo "[entrypoint] Starting MariaDB..."
exec mysqld --user=mysql --datadir=/var/lib/mysql --bind-address=0.0.0.0
