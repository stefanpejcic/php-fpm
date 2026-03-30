FROM php:8.4-fpm-alpine

# Runtime dependencies
RUN apk add --no-cache \
    libpng \
    libjpeg-turbo \
    libwebp \
    freetype \
    icu-libs \
    tidyhtml-libs \
    yaml \
    libzip \
    util-linux \
    imagemagick \
    imagemagick-libs \
    libpq \
    libgomp \
    libintl \
    gettext-libs \
    libsodium

# Build dependencies - removed after compilation
RUN apk add --no-cache --virtual .build-deps \
        $PHPIZE_DEPS \
        libpng-dev \
        libjpeg-turbo-dev \
        libwebp-dev \
        freetype-dev \
        icu-dev \
        tidyhtml-dev \
        yaml-dev \
        libzip-dev \
        util-linux-dev \
        imagemagick-dev \
        postgresql-dev \
        gettext-dev \
        libsodium-dev \
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
    && pecl install igbinary \
    && pecl install msgpack \
    && pecl install apcu \
    && pecl install --configureoptions 'enable-redis-igbinary="yes" enable-redis-msgpack="yes"' redis \
    && pecl install yaml \
    && pecl install uuid \
    && pecl install imagick \
    && docker-php-ext-enable \
        igbinary \
        msgpack \
        apcu \
        redis \
        yaml \
        uuid \
        imagick \
    && apk del .build-deps \
    && rm -rf /tmp/pear /tmp/* /var/cache/apk/*

# Socket directory
RUN mkdir -p /var/run/php && chmod 755 /var/run/php

# FPM pool config
COPY www.conf /usr/local/etc/php-fpm.d/www.conf

# FPM global config - routes startup/error/stop logs to Docker
COPY php-fpm.conf /usr/local/etc/php-fpm.conf

WORKDIR /var/www/html

CMD ["php-fpm", "--allow-to-run-as-root"]
