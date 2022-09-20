# Caddy on Docker

A Docker image for [Caddy](https://caddyserver.com).

## Examples

### Serve the current directory

```sh
docker run --rm -it \
  --publish 80:80/tcp \
  --publish 443:443/tcp \
  --publish 443:443/udp \
  --mount type=bind,src="$PWD",dst=/var/www/html/,ro \
  docker.io/hectorm/caddy:latest
```

### Serve `/var/www/html/` directory and use `/etc/caddy/Caddyfile` file as config

```sh
docker run --rm -it \
  --publish 80:80/tcp \
  --publish 443:443/tcp \
  --publish 443:443/udp \
  --mount type=bind,src=/etc/caddy/Caddyfile,dst=/etc/caddy/Caddyfile,ro \
  --mount type=bind,src=/var/www/html/,dst=/var/www/html/,ro \
  docker.io/hectorm/caddy:latest
```
