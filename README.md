# Caddy 2 on Docker

A Docker image for [Caddy](https://caddyserver.com).

## Examples

### Serve the current directory

```sh
docker run --rm -it -v "$PWD":/var/www/html/:ro -p 2015:2015 docker.io/hectorm/caddy2:latest
```

### Serve `/var/www/html/` directory and use `/etc/caddy/Caddyfile` file as config

```sh
docker run --rm -it -v /etc/caddy/Caddyfile:/etc/caddy/Caddyfile:ro -v /var/www/html/:/var/www/html/:ro -p 2015:2015 docker.io/hectorm/caddy2:latest
```
