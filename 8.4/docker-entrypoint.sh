#!/bin/sh
set -e

POOL_CONF="/etc/php84/php-fpm.d/www.conf"
RESERVE_MB=64
WORKER_MB=80
PHP_MEMORY_MB=96

# read available memory
CGROUP_MEM_FILE="/sys/fs/cgroup/memory.max"
PROC_MEM_KB=$(grep MemTotal /proc/meminfo | awk '{print $2}')
TOTAL_RAM_MB=$(( PROC_MEM_KB / 1024 ))

if [ -f "$CGROUP_MEM_FILE" ]; then
    CGROUP_BYTES=$(cat "$CGROUP_MEM_FILE")
    if [ "$CGROUP_BYTES" != "max" ] && [ "$CGROUP_BYTES" -gt 0 ] 2>/dev/null; then
        TOTAL_RAM_MB=$(( CGROUP_BYTES / 1024 / 1024 ))
    fi
fi

AVAILABLE_MB=$(( TOTAL_RAM_MB - RESERVE_MB ))
[ "$AVAILABLE_MB" -lt 64 ] && AVAILABLE_MB=64

# read CPU cores
CGROUP_CPU_FILE="/sys/fs/cgroup/cpu.max"
CORES=$(nproc)

if [ -f "$CGROUP_CPU_FILE" ]; then
    CPU_MAX=$(cat "$CGROUP_CPU_FILE")
    QUOTA=$(echo "$CPU_MAX" | awk '{print $1}')
    PERIOD=$(echo "$CPU_MAX" | awk '{print $2}')
    if [ "$QUOTA" != "max" ] && [ "$QUOTA" -gt 0 ] && [ "$PERIOD" -gt 0 ]; then
        CORES=$(( (QUOTA + PERIOD - 1) / PERIOD ))
    fi
fi

[ "$CORES" -lt 1 ] && CORES=1

# pool values
MAX_CHILDREN=$(( AVAILABLE_MB / WORKER_MB ))
[ "$MAX_CHILDREN" -lt 2 ]   && MAX_CHILDREN=2
[ "$MAX_CHILDREN" -gt 100 ] && MAX_CHILDREN=100

START_SERVERS=$(( CORES ))
[ "$START_SERVERS" -lt 2 ]  && START_SERVERS=2
[ "$START_SERVERS" -gt 10 ] && START_SERVERS=10
[ "$START_SERVERS" -gt $(( MAX_CHILDREN / 2 )) ] && START_SERVERS=$(( MAX_CHILDREN / 2 ))

MIN_SPARE=1
MAX_SPARE=$(( START_SERVERS + 1 ))
[ "$MAX_SPARE" -ge "$MAX_CHILDREN" ] && MAX_SPARE=$(( MAX_CHILDREN - 1 ))
[ "$MAX_SPARE" -lt 2 ] && MAX_SPARE=2

# opcache
if [ "$TOTAL_RAM_MB" -lt 512 ]; then
    OPCACHE_MB=32
elif [ "$TOTAL_RAM_MB" -lt 2048 ]; then
    OPCACHE_MB=64
else
    OPCACHE_MB=128
fi

# save
echo "[entrypoint] RAM: ${TOTAL_RAM_MB}MB | CPUs: ${CORES} | workers: ${MAX_CHILDREN} (start: ${START_SERVERS}, spare: ${MIN_SPARE}-${MAX_SPARE}) | opcache: ${OPCACHE_MB}MB"

sed -i "s|^pm.max_children\s*=.*|pm.max_children = ${MAX_CHILDREN}|"      "$POOL_CONF"
sed -i "s|^pm.start_servers\s*=.*|pm.start_servers = ${START_SERVERS}|"   "$POOL_CONF"
sed -i "s|^pm.min_spare_servers\s*=.*|pm.min_spare_servers = ${MIN_SPARE}|" "$POOL_CONF"
sed -i "s|^pm.max_spare_servers\s*=.*|pm.max_spare_servers = ${MAX_SPARE}|" "$POOL_CONF"

sed -i "s|^php_admin_value\[memory_limit\].*|php_admin_value[memory_limit] = ${PHP_MEMORY_MB}M|"                   "$POOL_CONF"
sed -i "s|^php_admin_value\[opcache.memory_consumption\].*|php_admin_value[opcache.memory_consumption] = ${OPCACHE_MB}|" "$POOL_CONF"

# foreground, no daemonize
exec ["php-fpm", "--nodaemonize", "--force-stderr", "--allow-to-run-as-root"]
