#!/usr/bin/env bash

if [ "$SUPERVISOR_PHP_USER" != "root" ] && [ "$SUPERVISOR_PHP_USER" != "app" ]; then
    echo "You should set SUPERVISOR_PHP_USER to either 'app' or 'root'."
    exit 1
fi

if [ ! -z "$WWWUSER" ]; then
    usermod -u $WWWUSER app
fi

php /var/www/html/artisan key:generate
php /var/www/html/artisan cache:clear
php /var/www/html/artisan config:clear
php /var/www/html/artisan view:clear
php /var/www/html/artisan route:clear
php /var/www/html/artisan schedule:clear-cache
php /var/www/html/artisan optimize:clear
php /var/www/html/artisan optimize
php /var/www/html/artisan migrate --force
# php /var/www/html/artisan scout:sync

# Set correct ownership for Laravel application
chown -R app:app /var/www/html

# Make storage and public directories writable
chmod -R 755 /var/www/html
chmod -R 775 /var/www/html/storage /var/www/html/bootstrap/cache /var/www/html/public

# Explicitly create log directory with proper permissions
mkdir -p /var/www/html/storage/logs
chmod -R 775 /var/www/html/storage/logs
chown -R app:app /var/www/html/storage/logs

# Ensure FrankenPHP can write to its directories
mkdir -p /data/caddy /config/caddy
chown -R app:app /data/caddy /config/caddy
chmod -R 755 /data/caddy /config/caddy

if [ $# -gt 0 ]; then
    if [ "$SUPERVISOR_PHP_USER" = "root" ]; then
        exec "$@"
    else
        exec gosu $WWWUSER "$@"
    fi
else
    exec /usr/bin/supervisord -c /etc/supervisor/conf.d/supervisord.conf
fi
