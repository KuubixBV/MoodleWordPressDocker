#!/usr/bin/env bash
set -euo pipefail
source .env

WP_CLI="docker compose run --rm --user www-data wpcli --allow-root"
WP_DIR="./wordpress_data"
MARKER="${WP_DIR}/.wp-installed"
if [[ -f $MARKER ]]; then
  echo "ℹ️  WordPress already installed, skipping."
  exit 0
fi

wait_db() {
  for _ in {1..30}; do
    docker compose exec -T db mysqladmin ping -h db -u"${WORDPRESS_DB_USER}" -p"${WORDPRESS_DB_PASSWORD}" --silent && return
    sleep 2
  done
  echo "❌ MySQL not ready" >&2
  exit 1
}

wait_core_ready() {
  for _ in {1..30}; do
    docker compose exec -T wordpress test -f /var/www/html/wp-settings.php && return
    sleep 2
  done
  echo "❌ WordPress core files not found after 60 s" >&2
  exit 1
}

docker compose up -d db wordpress
wait_db
wait_core_ready

# CREATE wp-config.php with correct host!
if ! $WP_CLI config get DB_NAME --quiet 2>/dev/null; then
  $WP_CLI config create \
    --dbname="${WORDPRESS_DB_NAME}" \
    --dbuser="${WORDPRESS_DB_USER}" \
    --dbpass="${WORDPRESS_DB_PASSWORD}" \
    --dbhost="db:3306" \
    --skip-check
fi

if ! $WP_CLI core is-installed --quiet; then
  $WP_CLI core install \
    --url="${WP_SITE_URL}" \
    --title="${WP_SITE_TITLE}" \
    --admin_user="${WP_ROOT_ADMIN}" \
    --admin_password="${WP_ROOT_PASS}" \
    --admin_email="${WP_ROOT_MAIL}" \
    --locale="${WP_LOCALE}" \
    --skip-email
fi

if ! $WP_CLI role list --field=role | grep -q '^classroom_admin$'; then
  $WP_CLI role create classroom_admin "Admin" --clone=administrator
  $WP_CLI cap remove classroom_admin delete_users promote_users create_users add_users list_users
fi

$WP_CLI user update "${WP_ROOT_ADMIN}" --role=administrator --user_pass="${WP_ROOT_PASS}" --display_name="Root"

if ! $WP_CLI user get "${WP_ADMIN}" --field=ID &>/dev/null; then
  $WP_CLI user create "${WP_ADMIN}" "${WP_ADMIN_MAIL}" --user_pass="${WP_ADMIN_PASS}" --role=classroom_admin --display_name="Admin"
fi
$WP_CLI user update "${WP_ADMIN}" --role=classroom_admin --user_pass="${WP_ADMIN_PASS}" --display_name="Admin"

$WP_CLI option update blog_public 0
$WP_CLI option update siteurl "${WP_SITE_URL}"
$WP_CLI option update home    "${WP_SITE_URL}"
$WP_CLI config set FS_METHOD 'direct'      --type=constant
$WP_CLI config set WP_MEMORY_LIMIT '2048M' --type=constant
$WP_CLI config set FORCE_SSL_ADMIN true    --raw --type=constant

touch "$MARKER"
echo "✅ WordPress installed and configured!"
