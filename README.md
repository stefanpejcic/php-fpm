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

`PHPFPM_LISTEN=socket` (set by `opencli php-listen socket`) makes it listen on `/run/php/php-fpm-X.Y/www.sock` instead of port 9000.

Tunable with env vars: `PHPFPM_WORKER_MB`, `PHPFPM_RESERVE_MB`, `PHPFPM_MAX_CHILDREN_CAP`, `PHPFPM_MAX_CHILDREN`, `PHPFPM_START_SERVERS`, `PHPFPM_MIN_SPARE_SERVERS`, `PHPFPM_MAX_SPARE_SERVERS`, `PHPFPM_MAX_REQUESTS`, `PHPFPM_PM`.

`APP_UID`/`APP_GID` and the `/etc/hooks/...` mount from the old compose file are simply ignored.

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
