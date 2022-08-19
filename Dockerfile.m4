m4_changequote([[, ]])

##################################################
## "build" stage
##################################################

FROM docker.io/golang:1.19-bullseye AS build
m4_ifdef([[CROSS_QEMU]], [[COPY --from=docker.io/hectorm/qemu-user-static:latest CROSS_QEMU CROSS_QEMU]])

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
		mime-support \
		tzdata \
	&& rm -rf /var/lib/apt/lists/*

# Build Caddy
COPY --chown=root:root ./src/ /go/src/caddy/
RUN find /go/src/caddy/ -type d -not -perm 0755 -exec chmod 0755 '{}' ';'
RUN find /go/src/caddy/ -type f -not -perm 0644 -exec chmod 0644 '{}' ';'
WORKDIR /go/src/caddy/
RUN go mod download
RUN go test -v -short github.com/caddyserver/...
RUN go build -v -o ./caddy -ldflags '-s -w' ./main.go
RUN mv ./caddy /usr/bin/caddy
RUN file /usr/bin/caddy
RUN /usr/bin/caddy version
RUN /usr/bin/caddy list-modules --versions

##################################################
## "base" stage
##################################################

m4_ifdef([[CROSS_ARCH]], [[FROM docker.io/CROSS_ARCH/ubuntu:22.04]], [[FROM docker.io/ubuntu:22.04]]) AS base
m4_ifdef([[CROSS_QEMU]], [[COPY --from=docker.io/hectorm/qemu-user-static:latest CROSS_QEMU CROSS_QEMU]])

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
		libcap2-bin \
		mime-support \
		tzdata \
	&& rm -rf /var/lib/apt/lists/*

# Create unprivileged user
ENV CADDY_USER_UID=1000
RUN useradd -u "${CADDY_USER_UID:?}" -g 0 -s "$(command -v bash)" -Md "${CADDYPATH:?}" caddy

# Copy Caddy build
COPY --from=build --chown=root:root /usr/bin/caddy /usr/bin/caddy

# Copy Caddy config
COPY --chown=root:root ./config/caddy/ /etc/caddy/
RUN find /etc/caddy/ -type d -not -perm 0755 -exec chmod 0755 '{}' ';'
RUN find /etc/caddy/ -type f -not -perm 0644 -exec chmod 0644 '{}' ';'

# Add capabilities to the Caddy binary (this allows Caddy to bind to privileged ports
# without being root, but creates another layer that increases the image size)
m4_ifdef([[CROSS_QEMU]], [[RUN setcap cap_net_bind_service=+ep CROSS_QEMU]])
RUN setcap cap_net_bind_service=+ep /usr/bin/caddy

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
		curl \
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
ENV JQ_CLEANUP_SCRIPT='del(.apps.http.servers.srv0.routes[].handle[].hide)'
RUN perl -pe 's/\{env\.([0-9A-Z_]+)\}/$ENV{$1}/g' /etc/caddy/Caddyfile.json | jq --sort-keys . > /tmp/Caddyfile.json
RUN caddy adapt --config /etc/caddy/Caddyfile      --adapter caddyfile | jq --sort-keys "${JQ_CLEANUP_SCRIPT:?}" | diff /tmp/Caddyfile.json -
RUN caddy adapt --config /etc/caddy/Caddyfile.cue  --adapter cue       | jq --sort-keys "${JQ_CLEANUP_SCRIPT:?}" | diff /tmp/Caddyfile.json -
RUN caddy adapt --config /etc/caddy/Caddyfile.toml --adapter toml      | jq --sort-keys "${JQ_CLEANUP_SCRIPT:?}" | diff /tmp/Caddyfile.json -

# Run Caddy and validate HTTP request output
RUN caddy run --config /etc/caddy/Caddyfile --adapter caddyfile & sleep 5 && curl -fsS 'http://127.0.0.1:2015' | grep -q 'Welcome to Caddy!'

##################################################
## "main" stage
##################################################

FROM base AS main

# Dummy instruction so BuildKit does not skip the test stage
RUN --mount=type=bind,from=test,source=/mnt/,target=/mnt/
