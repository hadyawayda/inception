#!/bin/bash

# Check if MariaDB has been initialized
if [ ! -d /var/lib/mariadb/mysql ]; then
    echo "Initializing MariaDB database..."
    mysqld --initialize-insecure
    mysqld &
    sleep 10

    # Set root password
    if [ -f "$MARIADB_ROOT_PASSWORD_FILE" ]; then
        mysql -e "SET PASSWORD FOR 'root'@'%' = PASSWORD('$(cat $MARIADB_ROOT_PASSWORD_FILE)');"
        mysql -e "GRANT ALL PRIVILEGES ON *.* TO 'root'@'%';"
        mysql -e "FLUSH PRIVILEGES;"
    else
        echo "Root password not set, skipping root password configuration"
    fi

    mysqladmin -u root -p$(cat $MARIADB_ROOT_PASSWORD_FILE) shutdown
    sleep 5
fi

# Run MariaDB
exec mysqld
