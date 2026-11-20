# PHP-FPM Docker images for PHP 5.6 to 8.6 (Debian, amd64 + arm64)

[![Build](https://github.com/stefanpejcic/php-fpm/actions/workflows/build.yml/badge.svg)](https://github.com/stefanpejcic/php-fpm/actions/workflows/build.yml)
[![Docker Pulls](https://img.shields.io/docker/pulls/openpanel/php-fpm)](https://hub.docker.com/r/openpanel/php-fpm)
[![Platforms](https://img.shields.io/badge/platforms-linux%2Famd64%20%7C%20linux%2Farm64-blue)](https://hub.docker.com/r/openpanel/php-fpm/tags)
[![PHP](https://img.shields.io/badge/PHP-5.6%20%E2%80%93%208.6-777bb4)](#supported-tags)
[![License: MIT](https://img.shields.io/badge/license-MIT-green)](LICENSE)

**`openpanel/php-fpm`** is a set of slim, fast-starting **PHP-FPM Docker images** based on **Debian**, one tag per PHP version from **PHP 5.6 to PHP 8.6**, built for **amd64 and arm64** (Apple Silicon, AWS Graviton, Raspberry Pi 4/5) and **rebuilt every night** with the latest PHP patch release and Debian security updates.

They are used by [OpenPanel](https://openpanel.com) to run PHP for every hosting account, and work standalone with **Docker, Docker Compose, Podman (also rootless) and Kubernetes**, behind **nginx, Apache, Caddy, OpenResty or Traefik**. Good for **WordPress, Laravel, Symfony, Drupal, Joomla, Magento, WooCommerce** and **legacy PHP 5.6 / 7.x applications**.

```bash
docker run -d --name php -m 512m -v ./site:/var/www/html -p 9000:9000 openpanel/php-fpm:8.4
```

## Contents

- [Why this image](#why-this-image)
- [Supported tags](#supported-tags)
- [Quick start](#quick-start)
- [Included PHP extensions and tools](#included-php-extensions-and-tools)
- [Configuration](#configuration)
- [PHP-FPM pool sizing](#php-fpm-pool-sizing)
- [Webserver examples](#webserver-examples)
- [Status and security scan](#status-and-security-scan)
- [FAQ](#faq)
- [Building](#building)

## Why this image

- **Fast start, ready in a few hundred milliseconds**: one small shell script writes the pool config and `exec`s php-fpm. No init system, no cron, no `chown -R` of your files, no startup hooks.
- **Small**: built on the [official `php` images](https://hub.docker.com/_/php), compiler toolchain removed, squashed to one layer, about **70-90 MB download**.
- **Auto-tuned PHP-FPM**: `pm.max_children` and spare servers are calculated from the container memory limit at every start.
- **Batteries included**: 20+ common extensions (gd, intl, redis, apcu, opcache, zip, pdo_mysql, pdo_pgsql...), Composer, and one-command extension installs (`phpaddmod imagick`).
- **Old PHP still works**: PHP 5.6, 7.0-7.4 and 8.0 are kept buildable on archived Debian releases, so legacy apps keep running and you can still install extensions.
- **Multi-arch**: native amd64 and arm64 builds, both tested before a tag is published.
- **Transparent**: every build is tested and scanned with Trivy, results are published in the [status table](#status-and-security-scan).

## Supported tags

| Tag | PHP | Debian base | Notes |
|---|---|---|---|
| `openpanel/php-fpm:8.6` | 8.6 | trixie | pre-release (RC) until PHP 8.6 GA, PECL extensions added as they gain support |
| `openpanel/php-fpm:8.5` | 8.5 | trixie | |
| `openpanel/php-fpm:8.4` | 8.4 | trixie | |
| `openpanel/php-fpm:8.3` | 8.3 | trixie | |
| `openpanel/php-fpm:8.2` | 8.2 | trixie | |
| `openpanel/php-fpm:8.1` | 8.1 | trixie | PHP EOL |
| `openpanel/php-fpm:8.0` | 8.0 | bullseye | PHP EOL |
| `openpanel/php-fpm:7.4` | 7.4 | bullseye | PHP EOL |
| `openpanel/php-fpm:7.3` | 7.3 | bullseye | PHP EOL |
| `openpanel/php-fpm:7.2` | 7.2 | buster | PHP EOL |
| `openpanel/php-fpm:7.1` | 7.1 | buster | PHP EOL |
| `openpanel/php-fpm:7.0` | 7.0 | stretch | PHP EOL |
| `openpanel/php-fpm:5.6` | 5.6 | stretch | PHP EOL |

Every tag is multi-arch (`linux/amd64`, `linux/arm64`) and always points to the latest patch release of that PHP version. There is deliberately **no `latest` tag**: pin the PHP version your app needs. Exact versions, sizes and scan results are in the [status table](#status-and-security-scan).

## Quick start

### Docker

```bash
docker run -d --name php \
  -m 512m \
  -v ./site:/var/www/html \
  -p 9000:9000 \
  openpanel/php-fpm:8.4
```

Point your webserver's FastCGI to `php:9000` (see [webserver examples](#webserver-examples)).

### Docker Compose

A complete PHP-FPM + nginx example is in [`examples/`](examples/) ([`docker-compose.yml`](examples/docker-compose.yml), [`nginx.conf`](examples/nginx.conf)): `cd examples && docker compose up -d`, then open http://localhost:8080.

```yaml
services:
  php:
    image: openpanel/php-fpm:8.4
    volumes:
      - ./site:/var/www/html
      - ./php.ini:/usr/local/etc/php/php.ini:ro   # optional
    deploy:
      resources:
        limits:
          memory: 1G                              # the FPM pool is sized from this
```

### Podman

```bash
podman run -d --name php -m 512m -v ./site:/var/www/html:Z -p 9000:9000 docker.io/openpanel/php-fpm:8.4
```

Works with rootless Podman: root inside the container maps to your unprivileged user on the host, so files written by PHP belong to you.

## Included PHP extensions and tools

**Extensions enabled by default** (on every version unless noted):
`apcu` `bcmath` `calendar` `exif` `ftp` `gd` (jpeg, png, webp, freetype; avif on 8.1+) `gettext` `igbinary` `intl` `msgpack` `mysqli` `opcache` `pcntl` `pdo_mysql` `pdo_pgsql` `pgsql` `redis` `sodium` `tidy` `uuid` `yaml` `zip`, plus everything compiled into PHP (`curl`, `mbstring`, `openssl`, `pdo_sqlite`, `xml`, ...).

**Install more** (imagick, soap, xdebug, memcached, mongodb... anything [install-php-extensions](https://github.com/mlocati/docker-php-extension-installer) supports):

```bash
docker exec php phpaddmod imagick soap    # install (compiles if needed) and enable
docker exec php phpdelmod imagick         # disable
docker exec php kill -USR2 1              # reload php-fpm to apply
```

Extensions installed at runtime live in the container, so recreating it drops them. For a permanent set, build your own image `FROM openpanel/php-fpm:8.4` and run `phpaddmod` in it.

**Tools**: `composer` (2.x, 2.2 LTS on PHP < 7.2), `install-php-extensions`, `curl`, `unzip`, `less`, `ps`.

## Configuration

| What | How |
|---|---|
| php.ini | mount at `/usr/local/etc/php/php.ini`, extra snippets in `/usr/local/etc/php/conf.d/*.ini` |
| Document root | `/var/www/html` (working directory) |
| Listen | port `9000`, or a unix socket with `PHPFPM_LISTEN` |
| Pool user | `root` by default (`--allow-to-run-as-root` is added automatically), `APP_USER=www-data` for an unprivileged pool |
| Logs | php-fpm and PHP errors go to stderr (`docker logs`), no access log (the webserver already logs requests) |
| Health check | FastCGI `/ping` answers `pong`, status page at `/status/php-fpm` |
| ionCube Loader | mount the loader for your PHP version at `/usr/local/lib/php/extensions/ioncube_loader.so` and a `conf.d/docker-php-ext-ioncube.ini` with `zend_extension=/usr/local/lib/php/extensions/ioncube_loader.so` |
| WP-CLI | mount `wp-cli.phar` at `/usr/local/bin/wp`, then `docker exec php wp --allow-root ...` |

### Environment variables

| Variable | Default | |
|---|---|---|
| `APP_USER` / `APP_GROUP` | root | user the workers run as |
| `PHPFPM_LISTEN` | port | `port` (:9000), `socket` (`/run/php/php-fpm-X.Y/www.sock`), or any port / socket path |
| `PHPFPM_PM` | dynamic | `dynamic`, `static` or `ondemand` |
| `PHPFPM_MAX_REQUESTS` | 500 | worker is recycled after this many requests |
| `PHPFPM_WORKER_MB` | 64 | average RAM per worker used by the pool formula |
| `PHPFPM_RESERVE_MB` | 64 | RAM kept for the master process and opcache |
| `PHPFPM_MAX_CHILDREN_CAP` | 256 | upper limit for `pm.max_children` |
| `PHPFPM_MAX_CHILDREN`, `PHPFPM_START_SERVERS`, `PHPFPM_MIN_SPARE_SERVERS`, `PHPFPM_MAX_SPARE_SERVERS` | calculated | fixed values instead of the formula |

## PHP-FPM pool sizing

At every start the entrypoint reads the container memory limit (`/sys/fs/cgroup/memory.max`, set by `docker run -m` or the compose `memory` limit; host RAM when unlimited) and writes the pool config:

```
pm.max_children      = (RAM - 64MB) / 64MB   (min 2, max 256)
pm.start_servers     = max_children / 4      (min 2)
pm.min_spare_servers = max_children / 8      (min 1)
pm.max_spare_servers = max_children / 2
```

| Container memory | max_children | start_servers | spare servers |
|---|---|---|---|
| 512 MB | 7 | 2 | 1-3 |
| 1 GB | 15 | 3 | 1-7 |
| 2 GB | 31 | 7 | 3-15 |

The result is printed in the log: `[openpanel] PHP 8.5.12 | 1024MB | user root | listen 9000 | max_children=15 start=3 spare=1-7`.

- Only memory counts, not CPU. The values are calculated on start; a `USR2` reload (e.g. after a php.ini change) keeps them.
- `memory_limit` comes from your php.ini. The formula assumes 64 MB per worker on average; if every worker hits a large `memory_limit` at once, the kernel kills a worker (OOM), not the whole container. Raise `PHPFPM_WORKER_MB` for a more conservative pool.

Config files in `/usr/local/etc/php-fpm.d/` are read alphabetically, later wins: `www.conf` / `docker.conf` / `zz-docker.conf` from the official image, `zz-openpanel.conf` with this image's defaults (listen 9000, `clear_env = no`, stderr logging, `/ping`, `pm = dynamic`, `pm.max_requests = 500`, `pm.process_idle_timeout = 10s`), and `zz-runtime.conf` written at start (user, listen, pool size).

## Webserver examples

**nginx**

```nginx
location ~ \.php$ {
    include fastcgi_params;
    fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
    fastcgi_pass php:9000;
}
```

**Apache** (`mod_proxy_fcgi`)

```apache
<FilesMatch "\.php$">
    SetHandler "proxy:fcgi://php:9000"
</FilesMatch>
```

**Caddy**

```caddy
example.com {
    root * /var/www/html
    php_fastcgi php:9000
    file_server
}
```

The webserver needs the same files at the same path (`/var/www/html`), e.g. the same volume mounted in both containers.

## Status and security scan

Updated by every build: PHP and Debian version, PHP upstream support, compressed download size, when the tag was pushed, how long the build took, and a [Trivy](https://trivy.dev) vulnerability scan of the published image (amd64).

- **Vulns C / H / M / L**: critical / high / medium / low findings in the image's Debian packages.
- **Fixable C/H**: critical/high findings that already have a fix in Debian, the only ones that need action (normally the next nightly build picks them up). EOL Debian releases (PHP 5.6-8.0 images) no longer get fixes, so their totals only grow.
- PHP itself is compiled from source, not a Debian package, so PHP CVEs are not counted here; that's what the **PHP support** column is for.
- Full findings: *Security → Code scanning* (high/critical with a fix available) and each workflow run's summary.

<!-- status:start -->
| Tag | PHP | Debian | PHP support | Download amd64 / arm64 | Built (UTC) | Build time | Vulns C / H / M / L | Fixable C/H | Extensions |
|---|---|---|---|---|---|---|---|---|---|
| `openpanel/php-fpm:5.6` | 5.6.40 | 9 (stretch) | ⛔ EOL 2018-12 | 67 MB / 63 MB | 2026-11-20 09:35 | 1m51s / 2m23s | 17 / 70 / 33 / 26 | ⛔ Debian EOL, no updates | ✅ all |
| `openpanel/php-fpm:7.0` | 7.0.33 | 9 (stretch) | ⛔ EOL 2019-01 | 71 MB / 66 MB | 2026-11-20 09:35 | 2m17s / 2m49s | 17 / 74 / 34 / 28 | ⛔ Debian EOL, no updates | ✅ all |
| `openpanel/php-fpm:7.1` | 7.1.33 | 10 (buster) | ⛔ EOL 2019-12 | 73 MB / 71 MB | 2026-11-20 09:35 | 1m56s / 2m43s | 17 / 94 / 65 / 21 | ⛔ Debian EOL, no updates | ✅ all |
| `openpanel/php-fpm:7.2` | 7.2.34 | 10 (buster) | ⛔ EOL 2020-11 | 74 MB / 72 MB | 2026-11-20 09:35 | 2m57s / 2m56s | 15 / 73 / 55 / 19 | ⛔ Debian EOL, no updates | ✅ all |
| `openpanel/php-fpm:7.3` | 7.3.33 | 11 (bullseye) | ⛔ EOL 2021-12 | 72 MB / 71 MB | 2026-11-20 09:35 | 2m02s / 2m37s | 21 / 136 / 190 / 164 | ⛔ Debian EOL, no updates | ✅ all |
| `openpanel/php-fpm:7.4` | 7.4.33 | 11 (bullseye) | ⛔ EOL 2022-11 | 71 MB / 69 MB | 2026-11-20 09:35 | 2m58s / 2m36s | 14 / 127 / 186 / 163 | ⛔ Debian EOL, no updates | ✅ all |
| `openpanel/php-fpm:8.0` | 8.0.30 | 11 (bullseye) | ⛔ EOL 2023-11 | 72 MB / 70 MB | 2026-11-20 09:35 | 2m45s / 2m57s | 13 / 118 / 174 / 163 | ⛔ Debian EOL, no updates | ✅ all |
| `openpanel/php-fpm:8.1` | 8.1.34 | 13 (trixie) | ⛔ EOL 2025-12 | 86 MB / 85 MB | 2026-11-20 09:35 | 2m01s / 2m57s | 1 / 35 / 79 / 85 | ✅ none | ✅ all |
| `openpanel/php-fpm:8.2` | 8.2.36 | 13 (trixie) | 🟡 security until 2026-12 | 86 MB / 85 MB | 2026-11-20 09:35 | 1m54s / 2m45s | 1 / 35 / 79 / 85 | ✅ none | ✅ all |
| `openpanel/php-fpm:8.3` | 8.3.37 | 13 (trixie) | 🟡 security until 2027-12 | 87 MB / 86 MB | 2026-11-20 09:35 | 2m08s / 3m08s | 1 / 35 / 79 / 85 | ✅ none | ✅ all |
| `openpanel/php-fpm:8.4` | 8.4.28 | 13 (trixie) | 🟢 active until 2026-12 | 90 MB / 89 MB | 2026-11-20 09:35 | 2m10s / 3m33s | 1 / 35 / 79 / 85 | ✅ none | ✅ all |
| `openpanel/php-fpm:8.5` | 8.5.13 | 13 (trixie) | 🟢 active until 2027-12 | 92 MB / 91 MB | 2026-11-20 09:35 | 3m26s / 3m19s | 1 / 35 / 79 / 85 | ✅ none | ✅ all |
| `openpanel/php-fpm:8.6` | 8.6.0RC7 | 13 (trixie) | 🟢 active until 2028-12 | 92 MB / 90 MB | 2026-11-19 10:09 | 3m47s / 5m01s | 1 / 35 / 79 / 85 | ✅ none | ⚠️ missing apcu, igbinary, msgpack, redis, yaml |

_Updated automatically by the build workflow, last run 2026-11-20 09:36 UTC._
<!-- status:end -->

## FAQ

**How do I run PHP 5.6 or PHP 7.x in Docker today?**
Use `openpanel/php-fpm:5.6`, `:7.0` ... `:7.4`. The official images for these versions are no longer updated and their Debian releases are archived, so `apt-get` and extension installs fail there. These images point apt at `archive.debian.org`, so `phpaddmod` still works. They are rebuilt nightly, but PHP itself gets no more security fixes, so treat them as legacy and isolate them.

**How do I install a PHP extension in a running container?**
`docker exec <container> phpaddmod <extension>` (e.g. `imagick`, `soap`, `xdebug`, `memcached`), then reload with `kill -USR2 1` inside the container, or restart it.

**Does it work on ARM64 (Apple Silicon, AWS Graviton, Raspberry Pi)?**
Yes. Every tag is a multi-arch manifest for `linux/amd64` and `linux/arm64`, built and tested natively on both.

**How is this different from the official `php:fpm` image?**
It starts from the official image and adds: common extensions preinstalled, Composer, memory-based pool tuning, unix socket mode, `phpaddmod`/`phpdelmod`, no compiler toolchain (smaller), working apt on EOL PHP versions, nightly rebuilds, and a published Trivy scan.

**Why is there no `latest` tag?**
Upgrading the PHP minor version can break applications. Pin the version you need, e.g. `openpanel/php-fpm:8.4`; it still gets every 8.4.x patch release automatically.

**How do I run php-fpm as a non-root user?**
Set `APP_USER=www-data` (and optionally `APP_GROUP`). Root is the default because with rootless Podman/Docker, root in the container is already your unprivileged host user, and it avoids file permission issues on bind mounts.

**How do I use a unix socket instead of TCP port 9000?**
Set `PHPFPM_LISTEN=socket` (listens on `/run/php/php-fpm-X.Y/www.sock`) or `PHPFPM_LISTEN=/path/to.sock`, and share the directory with the webserver container.

**Can I use it with WordPress, Laravel or Composer projects?**
Yes. Mount the project at `/var/www/html`, point the webserver at it, and use `docker exec php composer install` or WP-CLI (`wp`). The extensions WordPress and Laravel need are included.

**Does it support ionCube Loader?**
Yes, mount the loader `.so` for your PHP version and an ini that enables it (see [Configuration](#configuration)). ionCube doesn't publish a loader for PHP 8.0.

**How fast does it start?**
Usually 0.3-0.7 s from `docker run` to accepting FastCGI connections.

## Building

- **GitHub Actions** ([`.github/workflows/build.yml`](.github/workflows/build.yml)): every night at 02:00 UTC, on push to `main`, and manually from *Actions → Build and publish → Run workflow* (optionally only some versions, e.g. `8.4 8.5`). Each version is built natively on amd64 and arm64 runners, tested with [`test.sh`](test.sh), published as a multi-arch tag, scanned with Trivy, and the status table above is updated.
- **Locally**: `./build.sh 8.4` (docker or podman), `./build.sh all`, `PUSH=1 ./build.sh 8.4` for a multi-arch push. Test with `./test.sh openpanel/php-fpm:8.4`.
- PHP versions and their base images are listed in [`versions.txt`](versions.txt).

Issues and pull requests are welcome.

## License

[MIT](LICENSE) - Stefan Pejcic <stefan@pejcic.rs> - https://github.com/stefanpejcic/php-fpm
