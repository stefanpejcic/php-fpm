#!/bin/bash
set -e

PHP_VERSION_TAG="$1"
[[ -z "$PHP_VERSION_TAG" ]] && { echo "Usage: $0 <php_version_tag (e.g. 8.3)>"; exit 1; }
[[ "$PHP_VERSION_TAG" =~ ^[0-9]+\.[0-9]+$ ]] || { echo "Error: PHP_VERSION_TAG must be in format number.number (e.g. 8.3)"; exit 1; }

if ! docker buildx version >/dev/null 2>&1; then
  echo "Buildx not found. Installing..."
  mkdir -p ~/.docker/cli-plugins
  curl -L -o ~/.docker/cli-plugins/docker-buildx https://github.com/docker/buildx/releases/download/v0.34.1/buildx-v0.34.1.linux-amd64
  chmod +x ~/.docker/cli-plugins/docker-buildx
  docker buildx version
fi

#docker buildx inspect --bootstrap

# --tag openpanel/php-fpm:latest --tag openpanel/php-fpm:$PHP_VERSION_TAG-$(date +%Y%m%d)
docker buildx build \
  --platform linux/amd64,linux/arm64 \
  --build-arg PHP_VERSION="$PHP_VERSION_TAG" \
  --tag openpanel/php-fpm:"$PHP_VERSION_TAG" \
  --push .
