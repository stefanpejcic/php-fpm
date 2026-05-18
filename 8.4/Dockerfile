FROM php:8.4-fpm-bookworm

# System dependencies
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
    imagemagick \
    libgomp1 \
    gettext \
    libgettextpo-dev \
    libsodium-dev \
    unzip \
    git \
    && rm -rf /var/lib/apt/lists/*

# PHP extensions
RUN docker-php-ext-configure gd \
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
        zip

# PECL extensions
RUN pecl install \
        igbinary \
        msgpack \
        apcu \
        yaml \
        uuid \
        imagick \
    && pecl install --configureoptions 'enable-redis-igbinary="yes" enable-redis-msgpack="yes"' redis \
    && docker-php-ext-enable \
        igbinary \
        msgpack \
        apcu \
        redis \
        yaml \
        uuid \
        imagick

# Socket directory
RUN mkdir -p /var/run/php && chmod 755 /var/run/php

# FPM pool config
COPY www.conf /usr/local/etc/php-fpm.d/www.conf
COPY docker-entrypoint.sh /docker-entrypoint.sh
RUN chmod +x /docker-entrypoint.sh

# FPM global config
COPY php-fpm.conf /usr/local/etc/php-fpm.conf

WORKDIR /var/www/html

ENTRYPOINT ["/docker-entrypoint.sh"]
