FROM dunglas/frankenphp:php8.4-bookworm

# Arguments
ARG WWWGROUP=1000
ARG WWWUSER=1000
ARG NODE_VERSION=22
ARG MYSQL_CLIENT="default-mysql-client"
ARG POSTGRES_VERSION=17

# Workdir
WORKDIR /var/www/html

# Environment variables
ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=UTC
ENV SUPERVISOR_FRANKENPHP_COMMAND="/usr/local/bin/frankenphp run --config /etc/caddy/Caddyfile"
ENV SUPERVISOR_QUEUE_COMMAND="/usr/local/bin/php /var/www/html/artisan queue:listen --tries=1 --timeout=240 --memory=128"
ENV SUPERVISOR_SCHEDULER_COMMAND="/usr/local/bin/php /var/www/html/artisan schedule:work"
ENV SUPERVISOR_PULSE_CHECK_COMMAND="/usr/local/bin/php /var/www/html/artisan pulse:check"
ENV SUPERVISOR_PULSE_COMMAND="/usr/local/bin/php /var/www/html/artisan pulse:work"
ENV SUPERVISOR_REVERB_COMMAND="/usr/local/bin/php /var/www/html/artisan reverb:start --host='0.0.0.0' --port=8080 --debug"
ENV SUPERVISOR_PHP_USER="app"
ENV PGSSLCERT=/tmp/postgresql.crt

# Define the timezone
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

# Install base dependencies
RUN apt-get update \
    && apt-get install -y gnupg gosu curl ca-certificates zip unzip git supervisor sqlite3 libcap2-bin libpng-dev python3 dnsutils librsvg2-bin fswatch ffmpeg nano vim librdkafka-dev libuv1-dev build-essential \
    && apt-get clean

# Install PHP extensions using install-php-extensions
RUN install-php-extensions \
    pgsql \
    pdo_pgsql \
    sqlite3 \
    pdo_sqlite \
    gd \
    imagick \
    inotify \
    curl \
    mongodb \
    imap \
    mysqli \
    pdo_mysql \
    mbstring \
    xml \
    zip \
    bcmath \
    soap \
    intl \
    readline \
    ldap \
    oauth \
    uuid \
    rdkafka \
    protobuf \
    grpc \
    msgpack \
    igbinary \
    redis \
    memcached \
    pcov \
    xdebug \
    openswoole \
    opcache

# Install uv extension via PECL
RUN pecl install channel://pecl.php.net/uv-0.3.0 \
    && docker-php-ext-enable uv

# Install Composer (if not already included)
RUN curl -sLS https://getcomposer.org/installer | php -- --install-dir=/usr/bin/ --filename=composer

# Add Node.js repository and install Node.js, npm, pnpm, bun, and Yarn
RUN curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg \
    && echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_$NODE_VERSION.x nodistro main" > /etc/apt/sources.list.d/nodesource.list \
    && apt-get update \
    && apt-get install -y nodejs \
    && npm install -g npm \
    && npm install -g pnpm \
    && npm install -g bun \
    && curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg | gpg --dearmor | tee /etc/apt/keyrings/yarn.gpg >/dev/null \
    && echo "deb [signed-by=/etc/apt/keyrings/yarn.gpg] https://dl.yarnpkg.com/debian/ stable main" > /etc/apt/sources.list.d/yarn.list \
    && apt-get update \
    && apt-get install -y yarn

# Add PostgreSQL repository and install PostgreSQL client
RUN curl -sS https://www.postgresql.org/media/keys/ACCC4CF8.asc | gpg --dearmor | tee /etc/apt/keyrings/pgdg.gpg >/dev/null \
    && echo "deb [signed-by=/etc/apt/keyrings/pgdg.gpg] http://apt.postgresql.org/pub/repos/apt bookworm-pgdg main" > /etc/apt/sources.list.d/pgdg.list \
    && apt-get update \
    && apt-get install -y postgresql-client-$POSTGRES_VERSION \
    && apt-get install -y $MYSQL_CLIENT \
    && apt-get -y autoremove \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Create app user and group
RUN groupadd --force -g $WWWGROUP app || true
RUN useradd -ms /bin/bash --no-user-group -g $WWWGROUP -u 1337 app || true
RUN usermod -a -G $WWWGROUP app || true

# Give FrankenPHP capability to bind to privileged ports
RUN setcap CAP_NET_BIND_SERVICE=+eip /usr/local/bin/frankenphp

# Give write access to FrankenPHP directories
RUN mkdir -p /data/caddy /config/caddy
RUN chown -R app:app /data/caddy /config/caddy

# Copy configuration files
COPY start-container.sh /usr/local/bin/start-container.sh
COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf
COPY php.ini /usr/local/etc/php/conf.d/99-app.ini
COPY Caddyfile /etc/caddy/Caddyfile
RUN chmod +x /usr/local/bin/start-container.sh

# Copy the application files
USER root
COPY . /var/www/html

# Set proper permissions for Laravel
RUN chown -R app:app /var/www/html \
    && chmod -R 755 /var/www/html \
    && chmod -R 775 /var/www/html/storage /var/www/html/bootstrap/cache /var/www/html/public

# Install Composer dependencies
RUN mkdir -p /.composer \
    && chmod -R ugo+rw /.composer \
    && composer install --ignore-platform-reqs --no-interaction --no-progress --working-dir=/var/www/html \
    && composer dump-autoload --optimize --classmap-authoritative --working-dir=/var/www/html

# Build the node app; Packages with npm
RUN su app -c "cd /var/www/html && npm install --no-save" \
    && su app -c "cd /var/www/html && npm run build"

EXPOSE 80
EXPOSE 443
EXPOSE 443/udp
EXPOSE 8080

ENTRYPOINT ["start-container.sh"]
