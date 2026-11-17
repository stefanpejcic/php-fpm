# openpanel/php-fpm

Slim Debian PHP-FPM images for [OpenPanel](https://openpanel.com), one tag per PHP version, for **amd64 and arm64**:

```
openpanel/php-fpm:5.6  7.0  7.1  7.2  7.3  7.4  8.0  8.1  8.2  8.3  8.4  8.5  8.6
```

They are drop-in replacements for the `shinsenter/php:X.Y-fpm` images OpenPanel used before: change only the `image:` line, everything else in the compose file keeps working (php.ini mounts, ionCube loader, wp-cli, `phpaddmod` extension installs, `APP_USER=root`, `php-fpm --allow-to-run-as-root`).

## Why

| | shinsenter/php | openpanel/php-fpm |
|---|---|---|
| start | s6 + bootstrap hooks, ownership check/`chown`, crontab, usermod | one shell script writes the pool file and `exec php-fpm` |
| ready in | seconds | ~100 ms |
| extra stuff | cron, msmtp, htop, s6, helper scripts | only `procps`, `less`, `unzip` |

## Status

Updated by every build: PHP and Debian version, PHP upstream support, compressed download size, when the tag was pushed, how long the build took, and a [Trivy](https://trivy.dev) scan of the published image (amd64).

- **Vulns C / H / M / L**: critical / high / medium / low findings in the image's Debian packages.
- **Fixable C/H**: critical/high ones that already have a fix in Debian, the only ones that need action (normally the next nightly build picks them up). EOL Debian releases (5.6-8.0) never get fixes, so their totals only grow.
- PHP itself is compiled from source and isn't a Debian package, so PHP CVEs are not counted here - that's what the **PHP support** column is for.
- Full findings: *Security → Code scanning* (high/critical with a fix available) and each run's summary.

<!-- status:start -->
_Filled in by the first workflow run._
<!-- status:end -->

## What's inside

- Base: official `php:X.Y-fpm-<debian>` image (stretch for 5.6/7.0, buster 7.1/7.2, bullseye 7.3–8.0, trixie 8.1+). EOL Debian releases are pointed at `archive.debian.org` so `apt` still works.
- Extensions (same set as before): apcu bcmath calendar exif ftp gd gettext igbinary intl msgpack mysqli opcache pcntl pdo_mysql pdo_pgsql pgsql redis sodium tidy uuid yaml zip. Brand-new versions (RC) get the PECL ones as soon as they support it - the nightly build picks them up.
- `composer` (2.2 LTS on PHP < 7.2), `install-php-extensions`, `phpaddmod` / `phpdelmod`.
- PHP-FPM listens on `9000`, logs to stderr, no access log (the webserver logs requests), `/ping` → `pong`.

## Startup

`openpanel-entrypoint` only:

1. sizes the pool from the container memory limit (`(RAM - 64MB) / 64MB` children, cap 256, same formula as OpenPanel's `fpm-tuning.sh`),
2. sets the pool user from `APP_USER` / `APP_GROUP` (default `www-data`) and the listen address (`PHPFPM_LISTEN`),
3. adds `--allow-to-run-as-root` when the user is root,
4. `exec php-fpm`.

`APP_UID`/`APP_GID` and the `/etc/hooks/...` mount from the old compose file are simply ignored.

## PHP-FPM config

Files in `/usr/local/etc/php-fpm.d/` are read alphabetically, later ones override earlier ones:

| File | Written | Contains |
|---|---|---|
| `www.conf`, `docker.conf`, `zz-docker.conf` | official php image | base `www` pool (access log removed) |
| `zz-openpanel.conf` | at build, same everywhere | listen 9000, `clear_env = no`, logs to stderr, `/ping`, `pm = dynamic`, `pm.max_requests = 500`, `pm.process_idle_timeout = 10s` |
| `zz-runtime.conf` | **at every container start** | pool `user`/`group`, `listen`, and `pm.*` sized from the container's resources |

### Pool size follows the container memory limit

At start the entrypoint reads `/sys/fs/cgroup/memory.max` (the compose `memory` limit, `PHP_FPM_X_Y_RAM` in OpenPanel), or host RAM when the container is unlimited:

```
max_children = (RAM - 64MB) / 64MB   (min 2, max 256)
start        = max_children / 4      (min 2)
min_spare    = max_children / 8      (min 1)
max_spare    = max_children / 2
```

| Container RAM | max_children | start | spare |
|---|---|---|---|
| 0.5G | 7 | 2 | 1-3 |
| 1G | 15 | 3 | 1-7 |
| 2G | 31 | 7 | 3-15 |

The result is printed in the container log, e.g. `[openpanel] PHP 8.5.12 | 1024MB | user root | listen 9000 | max_children=15 start=3 spare=1-7`.

- Only RAM counts, not CPU (same as OpenPanel's old `fpm-tuning.sh`).
- It's calculated on start only: changing a user's RAM recreates the container, so it recalculates. A USR2 reload (after php.ini changes) keeps the values.
- `php.ini` is separate: `memory_limit` etc. come from the mounted ini. The formula assumes 64MB per worker on average, so if every worker hits a 512M `memory_limit` at once the kernel kills a worker (OOM), not the container. Raise `PHPFPM_WORKER_MB` for a more conservative pool.

### Overrides (compose `environment:`)

| Variable | Default | |
|---|---|---|
| `PHPFPM_WORKER_MB` | 64 | average RAM per worker in the formula |
| `PHPFPM_RESERVE_MB` | 64 | RAM kept for the master process and opcache |
| `PHPFPM_MAX_CHILDREN_CAP` | 256 | upper limit for max_children |
| `PHPFPM_MAX_CHILDREN`, `PHPFPM_START_SERVERS`, `PHPFPM_MIN_SPARE_SERVERS`, `PHPFPM_MAX_SPARE_SERVERS` | calculated | fixed values, skip the formula |
| `PHPFPM_MAX_REQUESTS` | 500 | worker is recycled after this many requests |
| `PHPFPM_PM` | dynamic | `dynamic`, `static` or `ondemand` |
| `PHPFPM_LISTEN` | port | `port` (:9000), `socket` (`/run/php/php-fpm-X.Y/www.sock`, set by `opencli php-listen socket`), or any port / socket path |
| `APP_USER` / `APP_GROUP` | www-data | user the workers run as (OpenPanel uses root) |

## Usage

```yaml
  php-fpm-8.4:
    image: openpanel/php-fpm:8.4
    volumes:
      - html_data:/var/www/html/
      - ./php.ini/8.4.ini:/usr/local/etc/php/php.ini
      - /etc/openpanel/wordpress/wp-cli.phar:/usr/local/bin/wp:ro
      - /etc/openpanel/php/ioncube/ioncube_loader_lin_8.4.so:/usr/local/lib/php/extensions/ioncube_loader.so:ro
      - /etc/openpanel/php/ioncube_extension.ini:/usr/local/etc/php/conf.d/docker-php-ext-ioncube.ini:ro
    environment:
      - APP_USER=root
      - APP_GROUP=root
    command: php-fpm --allow-to-run-as-root
```

Install an extension in a running container: `docker exec php-fpm-8.4 phpaddmod imagick soap`
Disable one: `docker exec php-fpm-8.4 phpdelmod imagick`

## Building

- **GitHub Actions** (`.github/workflows/build.yml`): every night at 02:00 UTC, on push to `main`, and manually from *Actions → Build and publish → Run workflow* (optionally only some versions, e.g. `8.4 8.5`). Each version is built natively on amd64 and arm64 runners, tested with `test.sh`, and only then published as a multi-arch `openpanel/php-fpm:X.Y` tag. There is no `latest` tag.
- **Locally**: `./build.sh 8.4` (docker or podman), `./build.sh all`, `PUSH=1 ./build.sh 8.4` for a multi-arch push. Test with `./test.sh openpanel/php-fpm:8.4`.
- Versions and their base images are in `versions.txt`.

## License

MIT - Stefan Pejcic <stefan@pejcic.rs> - https://github.com/stefanpejcic/php-fpm
