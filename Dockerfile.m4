m4_changequote([[, ]])

##################################################
## "build" stage
##################################################

FROM --platform=${BUILDPLATFORM} docker.io/golang:1.24-bookworm AS build

# Environment
ENV GO111MODULE=on
ENV CGO_ENABLED=0
ENV GOOS=m4_ifdef([[CROSS_GOOS]], [[CROSS_GOOS]])
ENV GOARCH=m4_ifdef([[CROSS_GOARCH]], [[CROSS_GOARCH]])
ENV GOARM=m4_ifdef([[CROSS_GOARM]], [[CROSS_GOARM]])

# Install system packages
RUN export DEBIAN_FRONTEND=noninteractive \
	&& apt-get update \
	&& apt-get install -y --no-install-recommends \
		file \
		libcap2-bin \
		media-types \
		tzdata \
	&& rm -rf /var/lib/apt/lists/*

# Build Caddy
COPY --chown=root:root ./src/ /go/src/caddy/
RUN find /go/src/caddy/ -type d -not -perm 0755 -exec chmod 0755 '{}' ';'
RUN find /go/src/caddy/ -type f -not -perm 0644 -exec chmod 0644 '{}' ';'
WORKDIR /go/src/caddy/
RUN go mod download
RUN GODEBUG='rsa1024min=0' go test -v -short github.com/caddyserver/...
RUN go build -v -o ./caddy -ldflags '-s -w' ./main.go
RUN setcap cap_net_bind_service=+ep ./caddy
RUN mv ./caddy /usr/bin/caddy
RUN file /usr/bin/caddy
RUN /usr/bin/caddy version
RUN /usr/bin/caddy list-modules --versions

##################################################
## "base" stage
##################################################

m4_ifdef([[CROSS_ARCH]], [[FROM docker.io/CROSS_ARCH/ubuntu:24.04]], [[FROM docker.io/ubuntu:24.04]]) AS base

# Environment
ENV CADDYPATH=/var/lib/caddy
ENV CADDYLOGPATH=/var/log/caddy
ENV CADDYWWWPATH=/var/www/html
ENV XDG_CONFIG_HOME=/var/lib
ENV XDG_DATA_HOME=/var/lib

# Install system packages
RUN export DEBIAN_FRONTEND=noninteractive \
	&& apt-get update \
	&& apt-get install -y --no-install-recommends \
		ca-certificates \
		curl \
		media-types \
		tzdata \
	&& rm -rf /var/lib/apt/lists/*

# Create unprivileged user
RUN userdel -rf "$(id -nu 1000)" && useradd -u 1000 -g 0 -s "$(command -v bash)" -Md "${CADDYPATH:?}" caddy

# Copy Caddy build
COPY --from=build --chown=root:root /usr/bin/caddy /usr/bin/caddy

# Copy Caddy config
COPY --chown=root:root ./config/caddy/ /etc/caddy/
RUN find /etc/caddy/ -type d -not -perm 0755 -exec chmod 0755 '{}' ';'
RUN find /etc/caddy/ -type f -not -perm 0644 -exec chmod 0644 '{}' ';'

# Create $CADDYPATH directory (Caddy will use this directory to store certificates)
RUN mkdir -p "${CADDYPATH:?}" && chown caddy:root "${CADDYPATH:?}" && chmod 775 "${CADDYPATH:?}"

# Create $CADDYLOGPATH directory (although this directory is not used by default)
RUN mkdir -p "${CADDYLOGPATH:?}" && chown caddy:root "${CADDYLOGPATH:?}" && chmod 775 "${CADDYLOGPATH:?}"

# Create $CADDYWWWPATH directory
RUN mkdir -p "${CADDYWWWPATH:?}" && chown caddy:root "${CADDYWWWPATH:?}" && chmod 775 "${CADDYWWWPATH:?}"
RUN HTML_FORMAT='<!DOCTYPE html><title>%s</title><h1>%s</h1>\n'; WELCOME_ARG='Welcome to Caddy!'; \
	printf "${HTML_FORMAT:?}" "${WELCOME_ARG:?}" "${WELCOME_ARG:?}" > "${CADDYWWWPATH:?}"/index.html

# Drop root privileges
USER caddy:root

ENTRYPOINT ["/usr/bin/caddy"]
CMD ["run", "--config", "/etc/caddy/Caddyfile", "--adapter", "caddyfile"]

##################################################
## "test" stage
##################################################

FROM base AS test

# Install system packages
USER root:root
RUN export DEBIAN_FRONTEND=noninteractive \
	&& apt-get update \
	&& apt-get install -y --no-install-recommends \
		diffutils \
		jq \
		perl \
	&& rm -rf /var/lib/apt/lists/*
USER caddy:root

# Validate configurations
RUN caddy validate --config /etc/caddy/Caddyfile.json
RUN caddy validate --config /etc/caddy/Caddyfile      --adapter caddyfile
RUN caddy validate --config /etc/caddy/Caddyfile.cue  --adapter cue
RUN caddy validate --config /etc/caddy/Caddyfile.toml --adapter toml

# Compare configurations against the reference JSON
ENV JQ_CLEANUP_SCRIPT='walk(if (type == "object" and .handler == "file_server") then del(.hide) else . end)'
RUN perl -pe 's/\{env\.([0-9A-Z_]+)\}/$ENV{$1}/g' /etc/caddy/Caddyfile.json | jq --sort-keys . > /tmp/Caddyfile.json
RUN caddy adapt --config /etc/caddy/Caddyfile      --adapter caddyfile | jq --sort-keys "${JQ_CLEANUP_SCRIPT:?}" | diff /tmp/Caddyfile.json -
RUN caddy adapt --config /etc/caddy/Caddyfile.cue  --adapter cue       | jq --sort-keys "${JQ_CLEANUP_SCRIPT:?}" | diff /tmp/Caddyfile.json -
RUN caddy adapt --config /etc/caddy/Caddyfile.toml --adapter toml      | jq --sort-keys "${JQ_CLEANUP_SCRIPT:?}" | diff /tmp/Caddyfile.json -

# Run Caddy and validate HTTP request output
RUN caddy run --config /etc/caddy/Caddyfile --adapter caddyfile & \
	timeout 60 sh -euc 'until curl -fsSLkv "http://localhost:80" | grep -q "Welcome to Caddy!"; do sleep 1; done'

##################################################
## "main" stage
##################################################

FROM base AS main

# Dummy instruction so BuildKit does not skip the test stage
RUN --mount=type=bind,from=test,source=/mnt/,target=/mnt/
