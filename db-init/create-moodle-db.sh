#!/bin/bash
set -e

# Wait for MariaDB to be ready
until mysql -uroot -p"$MYSQL_ROOT_PASSWORD" -e "SELECT 1" &>/dev/null; do
  echo "Waiting for MariaDB to be ready..."
  sleep 2
done

# Create Moodle database and user
mysql -uroot -p"$MYSQL_ROOT_PASSWORD" <<EOSQL
CREATE DATABASE IF NOT EXISTS \`${MOODLE_DB_NAME}\`;
CREATE USER IF NOT EXISTS '${MOODLE_DB_USER}'@'%' IDENTIFIED BY '${MOODLE_DB_PASSWORD}';
GRANT ALL PRIVILEGES ON \`${MOODLE_DB_NAME}\`.* TO '${MOODLE_DB_USER}'@'%';
FLUSH PRIVILEGES;
EOSQL
