FROM php:8.4-fpm-bookworm AS builder

RUN apt-get update && apt-get install -y --no-install-recommends \
        libpng-dev \
        libjpeg62-turbo-dev \
        libwebp-dev \
        libfreetype6-dev \
        libicu-dev \
        libtidy-dev \
        libyaml-dev \
        libzip-dev \
        libpq-dev \
        libmagickwand-dev \
        libsodium-dev \
        unzip \
        git \
    && docker-php-ext-configure gd \
        --with-freetype \
        --with-jpeg \
        --with-webp \
    && docker-php-ext-install -j$(nproc) \
        bcmath \
        calendar \
        exif \
        gd \
        gettext \
        intl \
        mysqli \
        opcache \
        pcntl \
        pdo_mysql \
        pdo_pgsql \
        pgsql \
        sodium \
        tidy \
        zip \
    && pecl install \
        igbinary \
        msgpack \
        apcu \
        yaml \
        uuid \
        imagick \
    && pecl install \
        --configureoptions 'enable-redis-igbinary="yes" enable-redis-msgpack="yes"' \
        redis \
    && docker-php-ext-enable \
        igbinary \
        msgpack \
        apcu \
        redis \
        yaml \
        uuid \
        imagick \
    && rm -rf /var/lib/apt/lists/* /tmp/pear

FROM php:8.4-fpm-bookworm AS final

RUN apt-get update && apt-get install -y --no-install-recommends \
        libpng16-16 \
        libjpeg62-turbo \
        libwebp7 \
        libfreetype6 \
        libicu72 \
        libtidy5deb1 \
        libyaml-0-2 \
        libzip4 \
        libpq5 \
        libmagickwand-6.q16-6 \
        imagemagick \
        libgomp1 \
        libsodium23 \
        ca-certificates \
    && rm -rf /var/lib/apt/lists/* /usr/share/doc /usr/share/man

COPY --from=builder /usr/local/lib/php/extensions/ /usr/local/lib/php/extensions/
COPY --from=builder /usr/local/etc/php/conf.d/ /usr/local/etc/php/conf.d/

# -v /path/to/ioncube/ioncube_loader_lin_8.4.so:/usr/local/lib/php/extensions/no-debug-non-zts-XXXXXXXX/ioncube_loader_lin_8.4.so
# Add to php.ini: zend_extension=ioncube_loader_lin_8.4.so
# IonCube must be the FIRST zend_extension loaded

RUN mkdir -p /usr/local/lib/ioncube

RUN mkdir -p /var/run/php && chmod 755 /var/run/php

COPY www.conf /usr/local/etc/php-fpm.d/www.conf
COPY php-fpm.conf /usr/local/etc/php-fpm.conf
COPY docker-entrypoint.sh /docker-entrypoint.sh
RUN chmod +x /docker-entrypoint.sh

WORKDIR /var/www/html
ENTRYPOINT ["/docker-entrypoint.sh"]
