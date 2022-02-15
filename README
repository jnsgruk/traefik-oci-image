# Traefik OCI Image

This repository contains the source for creating a Ubuntu-based OCI image for Traefik.

The build is composed of three stages:

- Building the web UI/dashboard
- Building Traefik
- Creating a Ubuntu based container with the Traefik binary

The resulting container is based on `ubuntu:focal`. The default user is `traefik`, and the directory
`/etc/traefik` is owned by that user.

## Building

You can build the image like so (note that setting the build arg is mandatory):

```bash

$ docker build -t jnsgruk/traefik  --build-arg TRAEFIK_VERSION=2.6.1 .
```

## Quick Validation

Once the image is build, you can test like so:

```bash
docker run \
  --rm \
  -p 127.0.0.1:8080:8080 \
  -it jnsgruk/traefik \
  --api.dashboard=true --api.insecure=true --log.level=DEBUG
```

You should then be able to visit [http://localhost:8080/dashboard/](http://localhost:8080/dashboard/).
