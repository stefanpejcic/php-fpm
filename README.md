# openpanel/php-fpm

Slim, fast-starting Debian PHP-FPM images, one tag per PHP version, for **amd64 and arm64**:

```
openpanel/php-fpm:5.6  7.0  7.1  7.2  7.3  7.4  8.0  8.1  8.2  8.3  8.4  8.5  8.6
```

Used by [OpenPanel](https://openpanel.com) for every user's PHP, and usable standalone with any Docker or Podman setup.

- **Fast start**: one small shell script writes the pool config and `exec`s php-fpm, ready in a few hundred ms. No init system, cron, `chown` or hooks at start.
- **Small**: built on the official `php` images, compiler toolchain removed, one flat layer (~70-90 MB download).
- **Sized from the container**: the FPM pool follows the container's memory limit.
- **Common extensions included**, more with one command (`phpaddmod imagick`).
- **Rebuilt every night** with the latest PHP patch release and Debian security updates.

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
- Extensions: apcu bcmath calendar exif ftp gd gettext igbinary intl msgpack mysqli opcache pcntl pdo_mysql pdo_pgsql pgsql redis sodium tidy uuid yaml zip. Brand-new versions (RC) get the PECL ones as soon as they support it - the nightly build picks them up.
- `composer` (2.2 LTS on PHP < 7.2), `install-php-extensions`, `phpaddmod` / `phpdelmod`.
- PHP-FPM listens on `9000`, logs to stderr, no access log (the webserver logs requests), `/ping` → `pong`.

## Startup

`openpanel-entrypoint` only:

1. sizes the pool from the container memory limit (`(RAM - 64MB) / 64MB` children, cap 256),
2. sets the pool user from `APP_USER` / `APP_GROUP` (default `root`) and the listen address (`PHPFPM_LISTEN`),
3. adds `--allow-to-run-as-root` when the user is root,
4. `exec php-fpm`.

## PHP-FPM config

Files in `/usr/local/etc/php-fpm.d/` are read alphabetically, later ones override earlier ones:

| File | Written | Contains |
|---|---|---|
| `www.conf`, `docker.conf`, `zz-docker.conf` | official php image | base `www` pool (access log removed) |
| `zz-openpanel.conf` | at build, same everywhere | listen 9000, `clear_env = no`, logs to stderr, `/ping`, `pm = dynamic`, `pm.max_requests = 500`, `pm.process_idle_timeout = 10s` |
| `zz-runtime.conf` | **at every container start** | pool `user`/`group`, `listen`, and `pm.*` sized from the container's resources |

### Pool size follows the container memory limit

At start the entrypoint reads `/sys/fs/cgroup/memory.max` (`docker run -m`, or the compose `memory` limit), or host RAM when the container is unlimited:

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

- Only RAM counts, not CPU.
- It's calculated on start only: changing the memory limit means recreating the container, so it recalculates. A USR2 reload (after php.ini changes) keeps the values.
- `php.ini` is separate: `memory_limit` etc. come from the mounted ini. The formula assumes 64MB per worker on average, so if every worker hits a 512M `memory_limit` at once the kernel kills a worker (OOM), not the container. Raise `PHPFPM_WORKER_MB` for a more conservative pool.

### Overrides (environment variables)

| Variable | Default | |
|---|---|---|
| `PHPFPM_WORKER_MB` | 64 | average RAM per worker in the formula |
| `PHPFPM_RESERVE_MB` | 64 | RAM kept for the master process and opcache |
| `PHPFPM_MAX_CHILDREN_CAP` | 256 | upper limit for max_children |
| `PHPFPM_MAX_CHILDREN`, `PHPFPM_START_SERVERS`, `PHPFPM_MIN_SPARE_SERVERS`, `PHPFPM_MAX_SPARE_SERVERS` | calculated | fixed values, skip the formula |
| `PHPFPM_MAX_REQUESTS` | 500 | worker is recycled after this many requests |
| `PHPFPM_PM` | dynamic | `dynamic`, `static` or `ondemand` |
| `PHPFPM_LISTEN` | port | `port` (:9000), `socket` (`/run/php/php-fpm-X.Y/www.sock`, used by OpenPanel's `opencli php-listen socket`), or any port / socket path |
| `APP_USER` / `APP_GROUP` | root | user the workers run as; `--allow-to-run-as-root` is added automatically for root. Set `www-data` for an unprivileged pool |

## Usage

```bash
docker run -d --name php -m 512m -v ./site:/var/www/html -p 9000:9000 openpanel/php-fpm:8.4
```

Point your webserver's FastCGI at `php:9000` (or use `PHPFPM_LISTEN=socket` and share `/run/php`). With compose:

```yaml
services:
  php-fpm-8.4:
    image: openpanel/php-fpm:8.4
    volumes:
      - ./site:/var/www/html
      - ./php.ini:/usr/local/etc/php/php.ini:ro    # optional, your own php.ini
    deploy:
      resources:
        limits:
          memory: 1G                               # pool size follows this
```

Workers run as root by default (`--allow-to-run-as-root` is added automatically). Set `APP_USER=www-data` for an unprivileged pool.

- **php.ini**: mount it at `/usr/local/etc/php/php.ini`, extra snippets go in `/usr/local/etc/php/conf.d/`.
- **ionCube**: mount the loader for your PHP version and enable it:
  `-v ./ioncube_loader_lin_8.4.so:/usr/local/lib/php/extensions/ioncube_loader.so:ro`
  `-v ./ioncube.ini:/usr/local/etc/php/conf.d/docker-php-ext-ioncube.ini:ro` with `zend_extension=/usr/local/lib/php/extensions/ioncube_loader.so`
- **wp-cli**: mount `wp-cli.phar` at `/usr/local/bin/wp`.
- **Extensions**: `docker exec php phpaddmod imagick soap` installs (compiles if needed) and enables them; `phpdelmod imagick` disables one. Restart the container or reload php-fpm (`kill -USR2 1`) to apply.
- **Health check**: FastCGI `/ping` answers `pong`.

## Building

- **GitHub Actions** (`.github/workflows/build.yml`): every night at 02:00 UTC, on push to `main`, and manually from *Actions → Build and publish → Run workflow* (optionally only some versions, e.g. `8.4 8.5`). Each version is built natively on amd64 and arm64 runners, tested with `test.sh`, and only then published as a multi-arch `openpanel/php-fpm:X.Y` tag. There is no `latest` tag.
- **Locally**: `./build.sh 8.4` (docker or podman), `./build.sh all`, `PUSH=1 ./build.sh 8.4` for a multi-arch push. Test with `./test.sh openpanel/php-fpm:8.4`.
- Versions and their base images are in `versions.txt`.

## License

MIT - Stefan Pejcic <stefan@pejcic.rs> - https://github.com/stefanpejcic/php-fpm
