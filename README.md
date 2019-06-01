# Caddy

A [Docker](https://docker.com) image for [Caddy](https://caddyserver.com/) without telemetry and with [all DNS providers](https://github.com/caddyserver/dnsproviders) included.

## Examples

### Serve current directory
```sh
docker run --rm -it -v "$PWD":/var/www/html/:ro -p 2015:2015 hectormolinero/caddy:latest
```

### Serve `/var/www/html/` and use `/etc/caddy/Caddyfile` as config
```sh
docker run --rm -it -v /etc/caddy/Caddyfile:/etc/caddy/Caddyfile:ro -v /var/www/html/:/var/www/html/:ro -p 2015:2015 hectormolinero/caddy:latest
```
