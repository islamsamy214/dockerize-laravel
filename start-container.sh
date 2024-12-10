#!/usr/bin/env bash

if [ "$SUPERVISOR_PHP_USER" != "root" ] && [ "$SUPERVISOR_PHP_USER" != "app" ]; then
    echo "You should set SUPERVISOR_PHP_USER to either 'app' or 'root'."
    exit 1
fi

if [ ! -z "$WWWUSER" ]; then
    usermod -u $WWWUSER app
fi

if [ ! -d /.composer ]; then
    mkdir /.composer
fi

chmod -R ugo+rw /.composer

composer install --ignore-platform-reqs --no-interaction --no-progress --working-dir=/var/www/html
php /var/www/html/artisan key:generate
php /var/www/html/artisan optimize
php /var/www/html/artisan cache:clear
php /var/www/html/artisan config:clear
php /var/www/html/artisan view:clear
php /var/www/html/artisan route:clear
php /var/www/html/artisan migrate --force
# php /var/www/html/artisan scout:sync

chown -R app:app /var/www/html
chmod -R 755 /var/www/html/storage /var/www/html/public

if [ $# -gt 0 ]; then
    if [ "$SUPERVISOR_PHP_USER" = "root" ]; then
        exec "$@"
    else
        exec gosu $WWWUSER "$@"
    fi
else
    exec /usr/bin/supervisord -c /etc/supervisor/conf.d/supervisord.conf
fi
