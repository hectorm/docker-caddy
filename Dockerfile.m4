m4_changequote([[, ]])

m4_ifdef([[CROSS_QEMU]], [[
##################################################
## "qemu-user-static" stage
##################################################

FROM ubuntu:18.04 AS qemu-user-static
RUN export DEBIAN_FRONTEND=noninteractive \
	&& apt-get update \
	&& apt-get install -y --no-install-recommends qemu-user-static
]])

##################################################
## "build-caddy" stage
##################################################

FROM golang:1-stretch AS build-caddy
m4_ifdef([[CROSS_QEMU]], [[COPY --from=qemu-user-static CROSS_QEMU CROSS_QEMU]])

# Copy patches
COPY patches/ /tmp/patches/

# Build Caddy
ARG CADDY_TREEISH=v0.11.5
ARG LEGO_TREEISH=v2.2.0
ARG DNSPROVIDERS_TREEISH=v0.1.3
RUN go get -v -d github.com/mholt/caddy \
	&& cd "${GOPATH}/src/github.com/mholt/caddy/caddy" \
	&& git checkout "${CADDY_TREEISH}"
RUN go get -v -d github.com/caddyserver/builds
RUN go get -v -d github.com/xenolf/lego/lego \
	&& cd "${GOPATH}/src/github.com/xenolf/lego/lego" \
	&& git checkout "${LEGO_TREEISH}"
RUN go get -v -d github.com/caddyserver/dnsproviders/... \
	&& cd "${GOPATH}/src/github.com/caddyserver/dnsproviders" \
	&& git checkout "${DNSPROVIDERS_TREEISH}"
RUN cd "${GOPATH}/src/github.com/mholt/caddy/caddy" \
	&& for f in /tmp/patches/caddy-*.patch; do [ -e "$f" ] || continue; git apply -v "$f"; done \
	&& export GOOS=m4_ifdef([[CROSS_GOOS]], [[CROSS_GOOS]]) \
	&& export GOARCH=m4_ifdef([[CROSS_GOARCH]], [[CROSS_GOARCH]]) \
	&& export GOARM=m4_ifdef([[CROSS_GOARM]], [[CROSS_GOARM]]) \
	&& export LDFLAGVARPKG='github.com/mholt/caddy/caddy/caddymain' \
	&& export LDFLAGS="-X ${LDFLAGVARPKG}.gitTag=${CADDY_TREEISH}" \
	&& go build -o ./caddy -ldflags "${LDFLAGS}" ./main.go \
	&& mv ./caddy /usr/bin/caddy \
	&& /usr/bin/caddy -version

##################################################
## "caddy" stage
##################################################

m4_ifdef([[CROSS_ARCH]], [[FROM CROSS_ARCH/ubuntu:18.04]], [[FROM ubuntu:18.04]]) AS caddy
m4_ifdef([[CROSS_QEMU]], [[COPY --from=qemu-user-static CROSS_QEMU CROSS_QEMU]])

# Environment
ENV CADDYPATH=/var/lib/caddy

# Install system packages
RUN export DEBIAN_FRONTEND=noninteractive \
	&& apt-get update \
	&& apt-get install -y --no-install-recommends \
		ca-certificates \
		libcap2-bin \
	&& rm -rf /var/lib/apt/lists/*

# Create users and groups
ARG CADDY_USER_UID=1000
ARG CADDY_USER_GID=1000
RUN groupadd \
		--gid "${CADDY_USER_GID}" \
		caddy
RUN useradd \
		--uid "${CADDY_USER_UID}" \
		--gid "${CADDY_USER_GID}" \
		--shell="$(which bash)" \
		--home-dir /home/caddy/ \
		--create-home \
		caddy

# Copy Caddy build
COPY --from=build-caddy --chown=root:root /usr/bin/caddy /usr/bin/caddy

# Add capabilities to the Caddy binary
RUN setcap cap_net_bind_service=+ep /usr/bin/caddy

# Copy Caddy config
COPY --chown=root:root ./config/caddy/Caddyfile /etc/caddy/Caddyfile

# Create web directory
RUN mkdir /srv/www/
RUN printf '%s\n' '<!DOCTYPE html><title>Welcome to Caddy!</title>' > /srv/www/index.html

# Create $CADDYPATH directory (Caddy will use this directory to store certificates)
RUN mkdir -p "${CADDYPATH}" && chown caddy:caddy "${CADDYPATH}" && chmod 700 "${CADDYPATH}"

# Drop root privileges
USER caddy:caddy

ENTRYPOINT ["/usr/bin/caddy"]
CMD ["-log=stdout", "-agree=true", "-conf=/etc/caddy/Caddyfile"]
