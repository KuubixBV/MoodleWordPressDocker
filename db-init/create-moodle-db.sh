#!/bin/bash
set -e

MARKER="/var/lib/mysql/.moodle-user-created"

if [ -f "$MARKER" ]; then
  echo "✅ Moodle DB and user already created; skipping."
  exit 0
fi

echo "MOODLE_DB_NAME=$MOODLE_DB_NAME"
echo "MOODLE_DB_USER=$MOODLE_DB_USER"

# Wait for MariaDB to be ready (just in case, safe if run at init)
until mysql -uroot -p"$MYSQL_ROOT_PASSWORD" -e "SELECT 1" &>/dev/null; do
  echo "Waiting for MariaDB to be ready..."
  sleep 2
done

# Create Moodle database and user if not present
mysql -uroot -p"$MYSQL_ROOT_PASSWORD" <<EOSQL
CREATE DATABASE IF NOT EXISTS \`${MOODLE_DB_NAME}\`;
CREATE USER IF NOT EXISTS '${MOODLE_DB_USER}'@'%' IDENTIFIED BY '${MOODLE_DB_PASSWORD}';
GRANT ALL PRIVILEGES ON \`${MOODLE_DB_NAME}\`.* TO '${MOODLE_DB_USER}'@'%';
FLUSH PRIVILEGES;
EOSQL

touch "$MARKER"
echo "✅ Moodle DB and user created!"
