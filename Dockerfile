FROM node:14.16 AS web_build

# Grab the TRAEFIK_VERSION from a build argument, fail out if unset.
ARG TRAEFIK_VERSION
RUN test -n "$TRAEFIK_VERSION"

# As per: https://github.com/traefik/traefik/raw/v2.6.1/webui/Dockerfile
ARG ARG_PLATFORM_URL=https://pilot.traefik.io
ARG PLATFORM_URL=${ARG_PLATFORM_URL}

# Get the Traefik source code, checking out the relevant tag for the $TRAEFIK_VERSION
RUN mkdir -p /src && \
    git clone -b v${TRAEFIK_VERSION} https://github.com/traefik/traefik /src/traefik

WORKDIR /src/traefik/webui

# Install the NodeJS dependencies for the dashboard
RUN npm install && \
    # Build the bundle as per:
    # https://github.com/traefik/traefik/blob/84a081054688349fa4e2513599e3bf2395331492/Makefile#L66
    npm run build:nc && \
    # Make things a little quicker to copy across into the next layer
    rm -rf node_modules

# Use an intermediate image that contains yq to parse the codename
FROM mikefarah/yq:4 AS yq
COPY --from=web_build --chown=yq:yq /src/traefik /src/traefik
# Run yq to parse .semaphore/semaphore.yml, output codename to file /src/traefik/codename
RUN yq e \
      '.blocks[] | select(.name=="Release").task.env_vars[] | select(.name=="CODENAME").value' \
      /src/traefik/.semaphore/semaphore.yml > /src/traefik/codename

# Next we need to build Traefik itself
FROM golang:1.17 AS traefik_build

ARG TRAEFIK_VERSION
ARG GO111MODULE=on
ARG CGO_ENABLED=0
ARG GOGC=off

# Grab the full source directory (and the built dashboard)
COPY --from=yq /src/traefik /root/traefik
WORKDIR /root/traefik

# Build Traefik from source
RUN mkdir -p dist && \
    go mod tidy && \
    # Required to merge non-code components into the final binary such as the web dashboard/UI
    go generate && \
    # Build Traefik per https://github.com/traefik/traefik/raw/v2.6.1/script/binary
    go build -ldflags "-s -w \
      -X github.com/traefik/traefik/v2/pkg/version.Version=$TRAEFIK_VERSION \
      -X github.com/traefik/traefik/v2/pkg/version.Codename=$(cat codename) \
      -X github.com/traefik/traefik/v2/pkg/version.BuildDate=$(date -u '+%Y-%m-%d_%I:%M:%S%p')" \
      -a -installsuffix nocgo -o dist/traefik ./cmd/traefik

FROM ubuntu:focal

# Copy across the built Traefik binary, ensure it's owned by root
COPY --from=traefik_build --chown=root:root /root/traefik/dist/traefik /usr/bin/traefik

# Create a traefik user and config directory
RUN useradd -M -r traefik && \
    mkdir /etc/traefik && \
    chown -R traefik:traefik /etc/traefik

USER traefik

# Run the traefik binary by default
ENTRYPOINT ["/usr/bin/traefik"]
