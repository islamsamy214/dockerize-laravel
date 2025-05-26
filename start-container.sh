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

chown -R app:app /var/www/html
chmod -R 775 /var/www/html/storage /var/www/html/public /var/www/html/bootstrap/cache
mkdir -p /var/www/html/storage/logs

# Ensure Apache logs are writable
mkdir -p /var/log/apache2
mkdir -p /var/run/apache2
touch /var/log/apache2/error.log /var/log/apache2/access.log
chown -R app:app /var/log/apache2
chown -R app:app /var/run/apache2
chmod -R 755 /var/log/apache2
chmod 644 /var/log/apache2/error.log /var/log/apache2/access.log

if [ $# -gt 0 ]; then
    if [ "$SUPERVISOR_PHP_USER" = "root" ]; then
        exec "$@"
    else
        exec gosu $WWWUSER "$@"
    fi
else
    exec /usr/bin/supervisord -c /etc/supervisor/conf.d/supervisord.conf
fi
