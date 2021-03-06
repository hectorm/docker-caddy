m4_changequote([[, ]])

##################################################
## "build" stage
##################################################

FROM docker.io/golang:1-buster AS build
m4_ifdef([[CROSS_QEMU]], [[COPY --from=docker.io/hectormolinero/qemu-user-static:latest CROSS_QEMU CROSS_QEMU]])

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
		tzdata

# Build Caddy
COPY --chown=root:root ./src/ /go/src/caddy/
WORKDIR /go/src/caddy/
RUN go mod download
RUN go build -v -o ./caddy -ldflags '-s -w' ./main.go
RUN mv ./caddy /usr/bin/caddy
RUN file /usr/bin/caddy
RUN /usr/bin/caddy -version

##################################################
## "base" stage
##################################################

m4_ifdef([[CROSS_ARCH]], [[FROM docker.io/CROSS_ARCH/ubuntu:20.04]], [[FROM docker.io/ubuntu:20.04]]) AS base
m4_ifdef([[CROSS_QEMU]], [[COPY --from=docker.io/hectormolinero/qemu-user-static:latest CROSS_QEMU CROSS_QEMU]])

# Environment
ENV CADDYPATH=/var/lib/caddy
ENV CADDYLOGPATH=/var/log/caddy
ENV CADDYWWWPATH=/var/www/html

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
COPY --chown=root:root ./config/caddy/Caddyfile /etc/caddy/Caddyfile

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

##################################################
## "test" stage
##################################################

FROM base AS test

RUN caddy -validate -conf /etc/caddy/Caddyfile

##################################################
## "caddy" stage
##################################################

FROM base AS caddy

ENTRYPOINT ["/usr/bin/caddy"]
CMD ["-conf=/etc/caddy/Caddyfile", "-root=/var/www/html", "-log=stdout", "-log-timestamps=false", "-agree=true"]
