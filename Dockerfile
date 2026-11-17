# syntax=docker/dockerfile:1
# openpanel/php-fpm - slim Debian php-fpm images for OpenPanel
# https://github.com/stefanpejcic/php-fpm

ARG BASE_TAG=8.5-fpm-trixie
ARG COMPOSER_VERSION=2

FROM composer/composer:${COMPOSER_VERSION}-bin AS composer
FROM mlocati/php-extension-installer:2 AS ipe

# ---- build: official php image + extensions, then the compiler toolchain is removed ----
FROM php:${BASE_TAG} AS build
COPY --from=ipe /usr/bin/install-php-extensions /usr/local/bin/install-php-extensions
COPY --from=composer /composer /usr/local/bin/composer
COPY build/setup.sh /tmp/setup.sh
RUN sh /tmp/setup.sh && rm -f /tmp/setup.sh
# scripts last, so changing them doesn't rebuild the extensions
COPY rootfs/ /

# ---- final: one flat layer, no gcc/perl/headers left behind ----
FROM scratch

ARG PHP_VERSION=8.5
ARG BASE_TAG
ARG VCS_REF=unknown
ARG BUILD_DATE=unknown

COPY --from=build / /

LABEL org.opencontainers.image.title="openpanel/php-fpm:${PHP_VERSION}" \
      org.opencontainers.image.description="Slim Debian PHP-FPM ${PHP_VERSION} image for OpenPanel" \
      org.opencontainers.image.authors="Stefan Pejcic <stefan@pejcic.rs>" \
      org.opencontainers.image.vendor="OpenPanel" \
      org.opencontainers.image.url="https://github.com/stefanpejcic/php-fpm" \
      org.opencontainers.image.source="https://github.com/stefanpejcic/php-fpm" \
      org.opencontainers.image.documentation="https://github.com/stefanpejcic/php-fpm#readme" \
      org.opencontainers.image.licenses="MIT" \
      org.opencontainers.image.revision="${VCS_REF}" \
      org.opencontainers.image.created="${BUILD_DATE}" \
      org.opencontainers.image.base.name="docker.io/library/php:${BASE_TAG}" \
      maintainer="Stefan Pejcic <stefan@pejcic.rs>"

# same environment the official php images set (lost by FROM scratch)
ENV PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin \
    PHP_VERSION=${PHP_VERSION} \
    PHP_INI_DIR=/usr/local/etc/php \
    PHPIZE_DEPS="autoconf dpkg-dev file g++ gcc libc-dev make pkg-config re2c" \
    PHP_CFLAGS="-fstack-protector-strong -fpic -fpie -O2 -D_LARGEFILE_SOURCE -D_FILE_OFFSET_BITS=64" \
    PHP_CPPFLAGS="-fstack-protector-strong -fpic -fpie -O2 -D_LARGEFILE_SOURCE -D_FILE_OFFSET_BITS=64" \
    PHP_LDFLAGS="-Wl,-O1 -pie" \
    COMPOSER_ALLOW_SUPERUSER=1 \
    COMPOSER_HOME=/.composer

WORKDIR /var/www/html
STOPSIGNAL SIGQUIT
EXPOSE 9000

ENTRYPOINT ["openpanel-entrypoint"]
CMD ["php-fpm"]
