#!/bin/bash
# Local build helper.
#   ./build.sh 8.4            build openpanel/php-fpm:8.4 for this machine (docker or podman)
#   ./build.sh all            build every version from versions.txt
#   PUSH=1 ./build.sh 8.4     multi-arch (amd64+arm64) build and push with docker buildx
set -euo pipefail
cd "$(dirname "$0")"

IMAGE="${IMAGE:-openpanel/php-fpm}"
PLATFORMS="${PLATFORMS:-linux/amd64,linux/arm64}"

base_exists() { # php:<tag> exists on Docker Hub?
    curl -fsSL -o /dev/null "https://hub.docker.com/v2/repositories/library/php/tags/$1"
}

build_one() {
    local v="$1" line base fallback composer
    line="$(awk -v v="$v" '$1==v' versions.txt)"
    [ -n "$line" ] || { echo "Unknown version $v (see versions.txt)" >&2; exit 1; }
    read -r _ base fallback composer <<<"$line"
    if [ "$fallback" != "-" ] && ! base_exists "$base"; then
        echo "php:$base not published yet, using php:$fallback"
        base="$fallback"
    fi

    local args=(--build-arg "PHP_VERSION=$v" --build-arg "BASE_TAG=$base" --build-arg "COMPOSER_VERSION=$composer"
                --build-arg "VCS_REF=$(git rev-parse --short HEAD 2>/dev/null || echo unknown)"
                --build-arg "BUILD_DATE=$(date -u +%Y-%m-%dT%H:%M:%SZ)" -t "$IMAGE:$v")
    echo "==> $IMAGE:$v  (php:$base, composer $composer)"
    if [ "${PUSH:-0}" = 1 ]; then
        docker buildx build --platform "$PLATFORMS" --push "${args[@]}" .
    elif command -v docker >/dev/null; then
        docker build "${args[@]}" .
    else
        podman build --format docker "${args[@]}" .
    fi
}

[ $# -ge 1 ] || { echo "Usage: $0 <version|all>"; exit 1; }
if [ "$1" = all ]; then
    for v in $(awk '!/^#/ && NF {print $1}' versions.txt); do build_one "$v"; done
else
    for v in "$@"; do build_one "$v"; done
fi
