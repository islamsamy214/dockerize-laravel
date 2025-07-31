FROM ubuntu:24.04

# Arguments
ARG WWWGROUP=1000
ARG WWWUSER=1000
ARG NODE_VERSION=22
ARG MYSQL_CLIENT="mysql-client"
ARG POSTGRES_VERSION=17

# Workdir
WORKDIR /var/www/html

# Environment variables
ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=UTC
# ENV SUPERVISOR_PHP_COMMAND="npx concurrently -c \"#93c5fd,#fb7185,#fdba74\" \"php -d variables_order=EGPCS /var/www/html/artisan serve --host=0.0.0.0 --port=80\" \"php artisan pail --timeout=0\" \"npm run dev\" --names=server,logs,vite"
ENV SUPERVISOR_PHP_COMMAND="/usr/bin/php -d variables_order=EGPCS /var/www/html/artisan octane:start --server=frankenphp --host=0.0.0.0 --port=80"
ENV SUPERVISOR_QUEUE_COMMAND="/usr/bin/php /var/www/html/artisan queue:listen --tries=1 --timeout=240 --memory=128"
ENV SUPERVISOR_SCHEDULER_COMMAND="/usr/bin/php /var/www/html/artisan schedule:work"
ENV SUPERVISOR_PULSE_CHECK_COMMAND="/usr/bin/php /var/www/html/artisan pulse:check"
ENV SUPERVISOR_PULSE_COMMAND="/usr/bin/php /var/www/html/artisan pulse:work"
# ENV SUPERVISOR_REVERB_COMMAND="/usr/bin/php /var/www/html/artisan reverb:start --host='0.0.0.0' --port=8080 --debug"
ENV SUPERVISOR_REVERB_COMMAND="/usr/bin/php /var/www/html/artisan reverb:start --host='0.0.0.0' --port=8080"
ENV SUPERVISOR_PHP_USER="app"
ENV PGSSLCERT=/tmp/postgresql.crt

# Define the timezone
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

# Set apt-get noninteractive
RUN echo "Acquire::http::Pipeline-Depth 0;" > /etc/apt/apt.conf.d/99custom && \
    echo "Acquire::http::No-Cache true;" >> /etc/apt/apt.conf.d/99custom && \
    echo "Acquire::BrokenProxy    true;" >> /etc/apt/apt.conf.d/99custom

# Install dependencies
RUN apt-get update && apt-get upgrade -y \
    # Install basic packages
    && mkdir -p /etc/apt/keyrings \
    && apt-get install -y gnupg gosu curl ca-certificates zip unzip git supervisor sqlite3 libcap2-bin libpng-dev python3 dnsutils librsvg2-bin fswatch ffmpeg nano vim librdkafka-dev libuv1-dev \
    # Install PHP and extensions
    && curl -sS 'https://keyserver.ubuntu.com/pks/lookup?op=get&search=0x14aa40ec0831756756d7f66c4f4ea0aae5267a6c' | gpg --dearmor | tee /etc/apt/keyrings/ppa_ondrej_php.gpg > /dev/null \
    && echo "deb [signed-by=/etc/apt/keyrings/ppa_ondrej_php.gpg] https://ppa.launchpadcontent.net/ondrej/php/ubuntu noble main" > /etc/apt/sources.list.d/ppa_ondrej_php.list \
    && apt-get update \
    && apt-get install -y php8.4 php8.4-cli php8.4-dev php-pear \
    php8.4-pgsql php8.4-sqlite3 php8.4-gd \
    php8.4-curl php8.4-mongodb \
    php8.4-imap php8.4-mysql php8.4-mbstring \
    php8.4-xml php8.4-zip php8.4-bcmath php8.4-soap \
    php8.4-intl php8.4-readline \
    php8.4-ldap \
    php8.4-oauth php8.4-uuid \
    php8.4-rdkafka \
    php8.4-protobuf php8.4-grpc \
    php8.4-msgpack php8.4-igbinary php8.4-redis \
    php8.4-memcached php8.4-pcov php8.4-imagick php8.4-xdebug php8.4-swoole \
    build-essential \
    # Install Composer
    && curl -sLS https://getcomposer.org/installer | php -- --install-dir=/usr/bin/ --filename=composer \
    && curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg \
    # Install FrankenPHP
    && curl https://frankenphp.dev/install.sh | sh \
    && mv frankenphp /usr/local/bin/ \
    # Install Node.js, npm, pnpm, bun, and Yarn
    && echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_$NODE_VERSION.x nodistro main" > /etc/apt/sources.list.d/nodesource.list \
    && apt-get update \
    && apt-get install -y nodejs \
    && npm install -g npm \
    && npm install -g pnpm \
    && npm install -g bun \
    && curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg | gpg --dearmor | tee /etc/apt/keyrings/yarn.gpg >/dev/null \
    && echo "deb [signed-by=/etc/apt/keyrings/yarn.gpg] https://dl.yarnpkg.com/debian/ stable main" > /etc/apt/sources.list.d/yarn.list \
    && curl -sS https://www.postgresql.org/media/keys/ACCC4CF8.asc | gpg --dearmor | tee /etc/apt/keyrings/pgdg.gpg >/dev/null \
    && echo "deb [signed-by=/etc/apt/keyrings/pgdg.gpg] http://apt.postgresql.org/pub/repos/apt noble-pgdg main" > /etc/apt/sources.list.d/pgdg.list \
    && apt-get update \
    && apt-get install -y yarn \
    && apt-get install -y $MYSQL_CLIENT \
    && apt-get install -y postgresql-client-$POSTGRES_VERSION \
    && apt-get -y autoremove \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Install PHP extensions
RUN apt-get update \
    && pecl install channel://pecl.php.net/uv-0.3.0 \
    && echo "extension=uv.so" > /etc/php/8.4/cli/conf.d/20-uv.ini

# Clean up
RUN apt-get -y autoremove \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Set PHP configuration
RUN setcap "cap_net_bind_service=+ep" /usr/bin/php8.4
RUN sysctl vm.overcommit_memory=1

# Create app user
RUN userdel -r ubuntu
RUN groupadd --force -g $WWWGROUP app
RUN useradd -ms /bin/bash --no-user-group -g $WWWGROUP -u 1337 -G sudo app

# Copy files
COPY start-container.sh /usr/local/bin/start-container.sh
COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf
COPY php.ini /etc/php/8.4/cli/conf.d/99-app.ini
COPY . .

# Set permissions
RUN chown -R app /var/www/html/storage /var/www/html/public
RUN chmod +x /usr/local/bin/start-container.sh
RUN chown -R app:app /var/www/html
RUN usermod -u $WWWUSER app

# Build the php app; Packages
RUN mkdir /.composer \
    && chmod -R ugo+rw /.composer \
    && composer install --ignore-platform-reqs --no-interaction --no-progress --working-dir=/var/www/html \
    && composer dump-autoload --optimize --no-dev --classmap-authoritative --working-dir=/var/www/html

# Build the node app; Packages with npm
RUN su app -c "cd /var/www/html && npm install --no-save" \
    && su app -c "cd /var/www/html && npm run build"

EXPOSE 80
EXPOSE 443
EXPOSE 443/udp
EXPOSE 2019

ENTRYPOINT ["start-container.sh"]
