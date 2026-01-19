FROM debian:bookworm

ARG RELEASE=3.3

# Install prerequisits
RUN apt-get update && apt-get install -y --no-install-recommends\
    nginx \
    php-fpm \
    curl \
    postgresql \
    postgresql-client \
    php-pgsql \
    php-mbstring \
    php-xml \
    php-curl \
    php-intl \
    python3-requests \
    python3-urllib3 \
    libxml2-utils \
    msmtp-mta \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Create and set workdir
RUN mkdir -p /opt/filesender

# Install release of filesender
RUN curl -fL https://github.com/filesender/filesender/archive/refs/tags/${RELEASE}.tar.gz | \
    tar -xz -C /opt/filesender; \
    mv /opt/filesender/filesender-${RELEASE} /opt/filesender/filesender

# Prepare the configuration
COPY config.php /opt/filesender/filesender/config/config.php
RUN cd /opt/filesender; \
    mkdir -p ./filesender/tmp ./filesender/files ./filesender/log; \
    chmod o-rwx ./filesender/tmp ./filesender/files ./filesender/log ./filesender/config/config.php; \
    chown -R www-data:www-data ./filesender

# Install SimpleSAMLphp
RUN curl -fL https://github.com/simplesamlphp/simplesamlphp/releases/download/v2.2.3/simplesamlphp-2.2.3-full.tar.gz | \
    tar -xz -C /opt/filesender; \
    mv /opt/filesender/simplesamlphp-2.2.3 /opt/filesender/simplesaml; \
    chown -R www-data:www-data /opt/filesender/simplesaml

RUN cd /opt/filesender/simplesaml/config; \
    mv acl.php.dist acl.php; \
    mv authsources.php.dist authsources.php; \
    sed -i -e "s@'entityID' => .*@'entityID' => 'https://localhost/simplesaml/module.php/saml/sp/metadata.php/default-sp',@g" authsources.php; \
    sed -i -e "s@'idp' => .*@'idp' => 'https://localhost/simplesaml/module.php/saml/idp/metadata.php',@g" authsources.php; \
    mv config.php.dist config.php; \
    cd /opt/filesender/simplesaml/metadata; \
    mv saml20-idp-hosted.php.dist saml20-idp-hosted.php; \
    mv saml20-idp-remote.php.dist saml20-idp-remote.php; \
    mv saml20-sp-remote.php.dist saml20-sp-remote.php

RUN mkdir -p /var/cache/simplesamlphp; \
    chown www-data:www-data /var/cache/simplesamlphp

# Configure password
RUN touch /opt/filesender/simplesaml/modules/admin/enable; \
    cd /opt/filesender/simplesaml/config; \
    SALT=$(LC_CTYPE=C tr -c -d '0123456789abcdefghijklmnopqrstuvwxyz' </dev/urandom | dd bs=32 count=1 2>/dev/null;echo); \
    sed -i -e "s@'secretsalt' => 'defaultsecretsalt'@'secretsalt' => '$SALT'@g" config.php; \
    sed -i -e "s@'auth.adminpassword' => '123'@'auth.adminpassword' => 'admin'@g" config.php

# Copy over the nginx configs
COPY ./nginx.conf /etc/nginx/nginx.conf
COPY filesender.conf /etc/nginx/sites-enabled/filesender
COPY fastcgi_params /etc/nginx/fastcgi_params
COPY create-certs.sh /create-certs.sh
RUN /create-certs.sh

# Config port
RUN sed -i -e "s@listen =.*@listen = 127.0.0.1:9090@g" /etc/php/8.2/fpm/pool.d/www.conf; \
    sed -i -e "s@.*catch_workers_output =.*@catch_workers_output = yes@g" /etc/php/8.2/fpm/pool.d/www.conf; \
    sed -i -e "s@.*access.log =.*@access.log = /proc/self/fd/2@g" /etc/php/8.2/fpm/pool.d/www.conf; \
    sed -i -e "s@.*decorate_workers_output =.*@decorate_workers_output = yes@g" /etc/php/8.2/fpm/pool.d/www.conf; \
    sed -i -e "s@.*error_log =.*@error_log = /proc/self/fd/2@g" /etc/php/8.2/fpm/php-fpm.conf


# configure and start postgres
RUN service postgresql start && \
    until pg_isready -q; do echo "waiting for postgres..."; sleep 1; done && \
    su - postgres -c "createuser -S -D -R filesender" && \
    su - postgres -c "psql -c \"ALTER ROLE filesender WITH PASSWORD 'filesender';\"" && \
    su - postgres -c "createdb -E UTF8 -O filesender filesender" && \
    php /opt/filesender/filesender/scripts/upgrade/database.php

# Configure php
RUN cd /opt/filesender; \
    cp ./filesender/config-templates/filesender-php.ini /etc/php/8.2/fpm/conf.d/99-filesender.ini; \
    cp ./filesender/config-templates/filesender-php.ini /etc/php/8.2/cli/conf.d/99-filesender.ini

# Configure the FileSender clean-up cron job
RUN cd /opt/filesender/filesender; \
    cp config-templates/cron/filesender /etc/cron.daily/filesender; \
    chmod +x /etc/cron.daily/filesender

# Configure saml to use https://mocksaml.com/
COPY configSAML.sh /opt/filesender/configSAML.sh
RUN curl -sS https://mocksaml.com/api/saml/metadata > /tmp/idp-metadata.xml && \
    /opt/filesender/configSAML.sh

# msmtp config (system-wide)
RUN printf '%s\n' \
    'defaults' \
    'auth off' \
    'tls off' \
    'logfile /dev/stdout' \
    '' \
    'account mailpit' \
    'host mailpit' \
    'port 1025' \
    'from filesender@example.com' \
    '' \
    'account default : mailpit' \
    > /etc/msmtprc \
    && chmod 0644 /etc/msmtprc
RUN printf '%s\n' \
    'sendmail_path = /usr/sbin/sendmail -t -i' \
    > /etc/php/8.2/fpm/conf.d/99-mailpit.ini

WORKDIR /opt/filesender

# make sure permissions are correct
RUN chown -R www-data:www-data /opt/filesender

# Start postgres and nginx
COPY entrypoint.sh /entrypoint.sh
ENTRYPOINT [ "/entrypoint.sh" ]
CMD ["nginx", "-g", "daemon off;"]