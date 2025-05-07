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
ENV SUPERVISOR_APACHE_COMMAND="/usr/sbin/apache2ctl -D FOREGROUND"
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
    && mkdir -p /etc/apt/keyrings \
    && apt-get install -y gnupg gosu curl ca-certificates zip unzip git supervisor sqlite3 libcap2-bin libpng-dev python3 dnsutils librsvg2-bin fswatch ffmpeg nano vim librdkafka-dev libuv1-dev

# Add PHP repository
RUN curl -sS 'https://keyserver.ubuntu.com/pks/lookup?op=get&search=0x14aa40ec0831756756d7f66c4f4ea0aae5267a6c' | gpg --dearmor | tee /etc/apt/keyrings/ppa_ondrej_php.gpg > /dev/null \
    && echo "deb [signed-by=/etc/apt/keyrings/ppa_ondrej_php.gpg] https://ppa.launchpadcontent.net/ondrej/php/ubuntu noble main" > /etc/apt/sources.list.d/ppa_ondrej_php.list

# Install PHP and extensions
RUN apt-get update \
    && apt-get install -y php8.2 php8.2-cli php8.2-dev php-pear \
    php8.2-pgsql php8.2-sqlite3 php8.2-gd \
    php8.2-curl php8.2-mongodb \
    php8.2-imap php8.2-mysql php8.2-mbstring \
    php8.2-xml php8.2-zip php8.2-bcmath php8.2-soap \
    php8.2-intl php8.2-readline \
    php8.2-ldap \
    php8.2-oauth php8.2-uuid \
    php8.2-rdkafka \
    php8.2-protobuf php8.2-grpc \
    php8.2-msgpack php8.2-igbinary php8.2-redis \
    php8.2-memcached php8.2-pcov php8.2-imagick php8.2-openswoole \
    build-essential \
    && pecl install channel://pecl.php.net/uv-0.3.0 \
    && echo "extension=uv.so" > /etc/php/8.2/cli/conf.d/20-uv.ini

# Install Composer
RUN  curl -sLS https://getcomposer.org/installer | php -- --install-dir=/usr/bin/ --filename=composer

# Install Node.js, npm, pnpm, bun, and yarn
RUN curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg \
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
    && apt-get install -y yarn

# Install Database clients
RUN apt-get update \
    && apt-get install -y $MYSQL_CLIENT \
    && apt-get install -y postgresql-client-$POSTGRES_VERSION

# Clean up
RUN apt-get -y autoremove \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Install Apache
RUN apt-get update && apt-get install -y apache2 libapache2-mod-php8.2 && rm -rf /var/lib/apt/lists/*

# Add Apache configuration for Laravel
COPY apache.conf /etc/apache2/sites-available/000-default.conf

# Bind port 80 to non-root user
RUN setcap "cap_net_bind_service=+ep" /usr/bin/php8.2
RUN sysctl vm.overcommit_memory=1
RUN update-alternatives --set php /usr/bin/php8.2
RUN setcap 'cap_net_bind_service=+ep' /usr/sbin/apache2

# Enable necessary Apache modules
RUN a2enmod rewrite

# Create app user
RUN userdel -r ubuntu
RUN groupadd --force -g $WWWGROUP app
RUN useradd -ms /bin/bash --no-user-group -g $WWWGROUP -u 1337 -G sudo app

# Copy files
COPY start-container.sh /usr/local/bin/start-container.sh
COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf
COPY php.ini /etc/php/8.2/cli/conf.d/99-app.ini
COPY composer.json composer.lock ./

# Configure Apache to run as app user
RUN echo 'export APACHE_RUN_USER=app' >> /etc/apache2/envvars
RUN echo 'export APACHE_RUN_GROUP=app' >> /etc/apache2/envvars

# Set permissions
RUN chmod +x /usr/local/bin/start-container.sh
RUN usermod -u $WWWUSER app

# Ensure Apache can write to run directory
RUN mkdir -p /var/run/apache2 \
    && chown -R app:app /var/run/apache2

# Run Composer install
RUN mkdir /.composer \
    && chmod -R ugo+rw /.composer \
    && composer install --ignore-platform-reqs --no-interaction --no-progress --working-dir=/var/www/html \
    && composer dump-autoload --optimize --no-dev --classmap-authoritative --working-dir=/var/www/html

# Expose port 80 for Apache
EXPOSE 80

ENTRYPOINT ["start-container.sh"]
