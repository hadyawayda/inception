#!/bin/bash

service mysql start

mysql -e "CREATE DATABASE IF NOT EXISTS wordpress;"
mysql -e "CREATE USER 'hady'@'%' IDENTIFIED BY 'hawayda';"
mysql -e "GRANT ALL PRIVILEGES ON wordpress.* TO 'hady'@'%';"
mysql -uroot -p hawayda -e "ALTER USER 'root'@'localhost' IDENTIFIED BY 'hawayda';"
mysql -e "FLUSH PRIVILEGES;"
mysqladmin -uroot -p hawayda shutdown

exec "$@"
