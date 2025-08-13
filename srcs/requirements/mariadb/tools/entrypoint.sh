#!/bin/bash

# Check if MariaDB has been initialized
if [ ! -d /var/lib/mariadb/mysql ]; then
    echo "Initializing MariaDB database..."
    mysqld --initialize-insecure
    mysqld &
    sleep 10

    ROOT_PASS="$(cat $MARIADB_ROOT_PASSWORD_FILE)"
    DB_PASS="$(cat $MARIADB_PASSWORD_FILE)"

    # Set root password
    mysql -u root -e "ALTER USER 'root'@'localhost' IDENTIFIED BY '${ROOT_PASS}';"
    mysql -u root -p"${ROOT_PASS}" -e "GRANT ALL PRIVILEGES ON *.* TO 'root'@'%' IDENTIFIED BY '${ROOT_PASS}' WITH GRANT OPTION; FLUSH PRIVILEGES;"

    # Create database and user for WordPress
    mysql -u root -p"${ROOT_PASS}" -e "CREATE DATABASE IF NOT EXISTS ${MARIADB_DATABASE} CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
    mysql -u root -p"${ROOT_PASS}" -e "CREATE USER IF NOT EXISTS '${MARIADB_USER}'@'%' IDENTIFIED BY '${DB_PASS}';"
    mysql -u root -p"${ROOT_PASS}" -e "GRANT ALL PRIVILEGES ON ${MARIADB_DATABASE}.* TO '${MARIADB_USER}'@'%'; FLUSH PRIVILEGES;"

    mysqladmin -u root -p"${ROOT_PASS}" shutdown
    sleep 5
fi

# Run MariaDB
exec mysqld
