#!/bin/bash
# Smoke test an image: ./test.sh openpanel/php-fpm:8.4
# Starts it like OpenPanel does (APP_USER=root, memory limit) and checks fpm, extensions, phpaddmod, composer.
set -euo pipefail
IMG="${1:?usage: $0 <image>}"
RT="${RT:-$(command -v docker || command -v podman)}"
NAME="phpfpm-test-$$"
trap '$RT rm -f "$NAME" "$NAME-sock" >/dev/null 2>&1 || true' EXIT

fail() { echo "FAIL: $*" >&2; $RT logs "$NAME" 2>&1 | tail -20 >&2; exit 1; }

$RT run -d --name "$NAME" -m 512m -e APP_USER=root -e APP_GROUP=root "$IMG" php-fpm --allow-to-run-as-root >/dev/null
for i in $(seq 1 50); do
    $RT exec "$NAME" sh -c "awk '\$4 == \"0A\"' /proc/net/tcp /proc/net/tcp6 2>/dev/null | grep -q ." 2>/dev/null && break
    sleep 0.1
done
$RT exec "$NAME" sh -c "awk '\$4 == \"0A\"' /proc/net/tcp /proc/net/tcp6 | grep -q ." || fail "php-fpm is not listening"
echo "ok   listening after ~$((i * 100))ms"

mods="$($RT exec "$NAME" php -m | tr '[:upper:]' '[:lower:]')"
for e in bcmath calendar exif ftp gd gettext intl mysqli pcntl pdo_mysql pdo_pgsql pgsql tidy zip uuid sodium "zend opcache" igbinary msgpack apcu yaml redis; do
    [ "$e" = sodium ] && e="sodium|libsodium"
    grep -qxE "$e" <<<"$mods" && echo "ok   ext $e" || echo "WARN ext $e missing"
done
$RT exec "$NAME" sh -c 'ps -eo user=,args= | grep "[p]ool www" | awk "{print \$1}" | sort -u' | grep -qx root || fail "workers are not running as root"
echo "ok   workers run as root"
$RT exec "$NAME" sh -c 'cat /usr/local/etc/php-fpm.d/zz-runtime.conf' | grep -q "max_children = 7" || fail "pool not sized for 512m"
echo "ok   pool sized from cgroup"
$RT exec "$NAME" composer --version >/dev/null 2>&1 && echo "ok   composer" || fail composer
$RT exec "$NAME" sh -c 'for d in /proc/[0-9]*; do case "$(tr "\0" " " < $d/cmdline 2>/dev/null)" in "php-fpm: master"*) kill -USR2 ${d#/proc/} && exit 0;; esac; done; exit 1' || fail "USR2 reload"
echo "ok   USR2 reload"
$RT exec "$NAME" phpaddmod calendar | grep -q "already installed" && echo "ok   phpaddmod (skip installed)"
# socket mode, as `opencli php-listen socket` sets it
$RT run -d --name "$NAME-sock" -e APP_USER=root -e PHPFPM_LISTEN=socket "$IMG" >/dev/null
ok=0
for i in $(seq 1 50); do
    $RT exec "$NAME-sock" sh -c "awk '\$8 ~ /^\/run\/php\/php-fpm-[0-9.]+\/www.sock/' /proc/net/unix | grep -q ." 2>/dev/null && { ok=1; break; }
    sleep 0.1
done
$RT rm -f "$NAME-sock" >/dev/null 2>&1
[ $ok = 1 ] && echo "ok   socket mode (PHPFPM_LISTEN=socket)" || fail "socket mode"
if [ "${FULL:-0}" = 1 ]; then
    $RT exec "$NAME" phpaddmod soap >/dev/null && $RT exec "$NAME" php -m | grep -qx soap && echo "ok   phpaddmod soap" || fail "phpaddmod soap"
fi
echo "PASS $IMG"
