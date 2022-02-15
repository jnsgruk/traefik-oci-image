# The first part stage of this build is per the build image supplied by the upstream:
# https://github.com/traefik/traefik/raw/v2.6.1/webui/Dockerfile
FROM node:14.16 AS web_build

# Grab the TRAEFIK_VERSION from a build argument, fail out if unset.
ARG TRAEFIK_VERSION
RUN test -n "$TRAEFIK_VERSION"

ARG ARG_PLATFORM_URL=https://pilot.traefik.io
ENV PLATFORM_URL=${ARG_PLATFORM_URL}

RUN mkdir -p /src && \
    git clone -b v${TRAEFIK_VERSION} https://github.com/traefik/traefik /src/traefik && \
    cd /src/traefik/webui && \
    # Install the NodeJS dependencies for the dashboard
    npm install && \
    # Build the bundle as per:
    # https://github.com/traefik/traefik/blob/84a081054688349fa4e2513599e3bf2395331492/Makefile#L66
    npm run build:nc && \
    # Make things a little quicker to copy across into the next layer
    rm -rf node_modules

# Next we need to build Traefik itself
FROM golang:1.17 AS traefik_build

ARG TRAEFIK_VERSION

ENV GO111MODULE=on
ENV CGO_ENABLED=0
ENV GOGC=off
ENV DEBIAN_FRONTEND=noninteractive

# Grab the full source directory (and the built dashboard)
COPY --from=web_build /src/traefik /root/traefik
WORKDIR /root/traefik

# Parse the release codename from semaphore.yaml
RUN apt-get update >/dev/null && \
    apt-get install -q -y --no-install-recommends python3-yaml jq >/dev/null && \
    cat .semaphore/semaphore.yml | \
      python3 -c "import yaml,sys,json; print(json.dumps(yaml.safe_load(sys.stdin)))" | \
      jq -r '.blocks[] | select(.name=="Release").task.env_vars[] | select(.name=="CODENAME").value' \
      > codename

# Fetch the go deps before the build (run in own layer for caching during build tests!)
RUN go mod tidy

RUN mkdir dist && \
    # Required to merge non-code components into the final binary
    # such as ther web dashboard/UI
    go generate && \
    # Setup environment variables to populate version correctly in build
    export VERSION="${TRAEFIK_VERSION}" && \
    export CODENAME="$(cat codename)" && \
    export DATE="$(date -u '+%Y-%m-%d_%I:%M:%S%p')" && \
    # Build Traefik 
    # As per https://github.com/traefik/traefik/raw/v2.6.1/script/binary
    go build -ldflags "-s -w \
      -X github.com/traefik/traefik/v2/pkg/version.Version=$VERSION \
      -X github.com/traefik/traefik/v2/pkg/version.Codename=$CODENAME \
      -X github.com/traefik/traefik/v2/pkg/version.BuildDate=$DATE" \
      -a -installsuffix nocgo -o dist/traefik ./cmd/traefik

FROM ubuntu:focal

# Copy across the built Traefik binary
COPY --from=traefik_build /root/traefik/dist/traefik /usr/bin/traefik

# Create a traefik user and config directory
RUN useradd -M -r traefik && \
    mkdir /etc/traefik && \
    chown -R traefik:traefik /etc/traefik

USER traefik

# Run the traefik binary by default
ENTRYPOINT ["/usr/bin/traefik"]