#!/bin/sh
# Build-time setup for openpanel/php-fpm. Runs once inside `docker build`, never at container start.
set -eu

PHP_MM="$(php -r 'echo PHP_MAJOR_VERSION.".".PHP_MINOR_VERSION;')"
PHP_ID="$(php -r 'echo PHP_VERSION_ID;')"
. /etc/os-release
CODENAME="${VERSION_CODENAME:-$(sed -n 's/^VERSION=.*(\(.*\)).*/\1/p' /etc/os-release)}"
echo "==> PHP ${PHP_MM} (${PHP_ID}) on Debian ${CODENAME} ($(uname -m))"

export DEBIAN_FRONTEND=noninteractive

# ---------------------------------------------------------------------------
# 1. EOL Debian releases (stretch, buster, bullseye) live on archive.debian.org.
#    Rewritten here once so apt (and phpaddmod at runtime) keeps working.
# ---------------------------------------------------------------------------
use_archive() {
    echo "==> switching apt to archive.debian.org for ${CODENAME}"
    rm -f /etc/apt/sources.list.d/*.list /etc/apt/sources.list.d/*.sources
    case "$CODENAME" in
        stretch|buster) sec="deb http://archive.debian.org/debian-security ${CODENAME}/updates main" ;;
        *)              sec="deb http://archive.debian.org/debian-security ${CODENAME}-security main" ;;
    esac
    printf 'deb http://archive.debian.org/debian %s main\n%s\n' "$CODENAME" "$sec" > /etc/apt/sources.list
    printf 'Acquire::Check-Valid-Until "false";\nAcquire::AllowInsecureRepositories "true";\nAPT::Get::AllowUnauthenticated "true";\n' \
        > /etc/apt/apt.conf.d/99openpanel-archive
}
# archive.debian.org and deb.debian.org time out now and then, retry instead of failing the build (also used by phpaddmod later)
printf 'Acquire::Retries "5";\nAcquire::http::Timeout "30";\nAcquire::https::Timeout "30";\n' > /etc/apt/apt.conf.d/80openpanel-retries
case "$CODENAME" in
    jessie|stretch|buster|bullseye) use_archive ;;
esac
apt_update() { for i in 1 2 3; do apt-get update -q && return 0; sleep $((i * 15)); done; return 1; }
if ! apt_update; then
    use_archive
    apt_update
fi

# ---------------------------------------------------------------------------
# 2. Tools OpenPanel runs inside the container (ps for install status, less for wp-cli, unzip for composer/wp)
# ---------------------------------------------------------------------------
for i in 1 2 3; do
    apt-get install -y -q --no-install-recommends procps less unzip ca-certificates curl xz-utils && break
    [ "$i" = 3 ] && exit 1; sleep $((i * 15)); apt_update || true
done

# ---------------------------------------------------------------------------
# 3. Extensions included by default
# ---------------------------------------------------------------------------
# AVIF needs libaom/libavif built from source on old Debian releases, skip it there
case "$CODENAME" in jessie|stretch|buster|bullseye) export IPE_GD_WITHOUTAVIF=1 ;; esac

loaded() {
    m="$1"
    case "$m" in opcache) m="zend opcache" ;; sodium) m="sodium|libsodium" ;; esac   # PHP 5.6 calls it libsodium
    php -m 2>/dev/null | tr '[:upper:]' '[:lower:]' | grep -qxE "$m"
}

REQUIRED="bcmath calendar exif ftp gd gettext intl mysqli opcache pcntl pdo_mysql pdo_pgsql pgsql tidy zip uuid"
# pecl extensions: required too, only a pre-release PHP (RC) may ship without the ones that don't support it yet
OPTIONAL="igbinary msgpack apcu yaml redis"
PRERELEASE=0; case "$(php -r 'echo PHP_VERSION;')" in *RC*|*alpha*|*beta*|*dev*) PRERELEASE=1 ;; esac

# pecl.php.net and the apt mirrors time out now and then, retry each install
ipe() { for i in 1 2 3; do install-php-extensions "$@" && return 0; echo "!!! install-php-extensions $* failed (attempt $i)"; sleep $((i * 20)); done; return 1; }
loaded sodium || REQUIRED="$REQUIRED sodium"

todo=""
for e in $REQUIRED; do loaded "$e" || todo="$todo $e"; done
opt=""
for e in $OPTIONAL; do loaded "$e" || opt="$opt $e"; done

# one install-php-extensions run is much faster (build deps installed/removed once)
# shellcheck disable=SC2086
if ! install-php-extensions $todo $opt; then
    echo "!!! combined install failed, retrying one by one"
    [ -n "$todo" ] && ipe $todo
    for e in $opt; do
        loaded "$e" && continue
        if ! ipe "$e"; then
            [ "$PRERELEASE" = 1 ] || { echo "!!! $e could not be installed for PHP ${PHP_MM}" >&2; exit 1; }
            echo "!!! WARNING: $e doesn't build on pre-release PHP ${PHP_MM} yet, skipping"
        fi
    done
fi

# ---------------------------------------------------------------------------
# 4. PHP-FPM config (version aware - older fpm rejects unknown directives)
# ---------------------------------------------------------------------------
# no per-request access log, the webserver already logs requests
sed -i '/^access\.log/d' /usr/local/etc/php-fpm.d/docker.conf

conf=/usr/local/etc/php-fpm.d/zz-openpanel.conf
{
    echo "; openpanel/php-fpm defaults - pool user and pm.* sizing are written at start to zz-runtime.conf"
    echo "[global]"
    echo "daemonize = no"
    echo "error_log = /proc/self/fd/2"
    echo "log_level = notice"
    echo "pid = /run/php-fpm.pid"
    echo
    echo "[www]"
    echo "listen = 9000"
    echo "clear_env = no"
    echo "catch_workers_output = yes"
    [ "$PHP_ID" -ge 70300 ] && echo "decorate_workers_output = no"
    echo "ping.path = /ping"
    echo "ping.response = pong"
    echo "pm.status_path = /status/php-fpm"
    echo "pm = dynamic"
    echo "pm.max_requests = 500"
    echo "pm.process_idle_timeout = 10s"
} > "$conf"

echo "fastcgi.logging = Off" > /usr/local/etc/php/conf.d/docker-fpm.ini

# ---------------------------------------------------------------------------
# 5. Cleanup (keep /usr/src/php.tar.xz and /usr/local/include/php - install-php-extensions needs it for bundled extensions)
# ---------------------------------------------------------------------------
docker-php-source delete 2>/dev/null || true
# The official Debian images keep gcc/g++/perl (~250MB) and install-php-extensions marks every package as manual.
# Keep only what PHP and its extensions link against (same trick the official php Dockerfile uses) plus a few tools,
# everything else goes. phpaddmod reinstalls the compiler when an extension has to be built.
apt-mark auto '.*' > /dev/null
for p in apt adduser ca-certificates curl xz-utils procps less unzip tzdata debian-archive-keyring openssl; do apt-mark manual "$p" > /dev/null 2>&1 || true; done
find /usr/local -type f \( -perm -u+x -o -name '*.so' \) -exec ldd '{}' ';' 2>/dev/null \
    | awk '/=>/ { so = $(NF-1); if (index(so, "/usr/local/") == 1) next; gsub("^/(usr/)?", "", so); printf "*%s\n", so }' \
    | sort -u | xargs -r dpkg-query --search 2>/dev/null | grep -v "^diversion" | cut -d: -f1 | tr -d " " | tr "," "\n" | sort -u | xargs -r apt-mark manual > /dev/null
apt-get purge -y -q --auto-remove -o APT::AutoRemove::RecommendsImportant=false
apt-get clean
rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* /root/.cache /root/.pearrc /usr/local/lib/php/.registry/.channel.*/*.tmp \
       /usr/local/lib/php/doc /usr/local/lib/php/test /usr/share/doc/* /usr/share/man/* /usr/share/info/*
mkdir -p /.composer /var/www/html
chmod 1777 /.composer

# ---------------------------------------------------------------------------
# 6. Sanity checks - the build fails here if something is broken
# ---------------------------------------------------------------------------
php -v
php -m
for e in $REQUIRED; do
    loaded "$e" || { echo "!!! $e is missing" >&2; exit 1; }
done
if [ "$PRERELEASE" = 0 ]; then
    for e in $OPTIONAL; do loaded "$e" || { echo "!!! $e is missing" >&2; exit 1; }; done
fi
php-fpm -t -R
composer --version --no-interaction 2>/dev/null | head -1
echo "==> done: PHP ${PHP_MM}"
