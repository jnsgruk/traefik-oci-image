# Traefik OCI Image

This repository contains the source for creating a Ubuntu-based OCI image for
[Traefik](https://traefik.io/).

The build is composed of three stages:

- Building the web UI/dashboard
- Building Traefik
- Creating a Ubuntu based container with the Traefik binary

The resulting container is based on `ubuntu:focal`. The default user is `traefik`, and the
directory `/etc/traefik` is owned by that user.

## Releasing a new version

To release a new version of the image, [create a Pull
Request](https://github.com/jnsgruk/traefik-oci-image/compare) ensuring that you update the
[`version`](./version) file to represent the **version of Traefik** you want the image to contain.

Once the PR's workflows have passed, merge the PR and tag the commit with the Traefik version on
the `main` branch, e.g.

```
git tag -a 2.6.1
git push origin 2.6.1
```

This will trigger a workflow to build the image, and publish to Docker Hub.

## Building / Testing

You can build the image like so (note that setting the build arg is mandatory):

```bash
$ docker build -t jnsgruk/traefik --build-arg TRAEFIK_VERSION="$(cat version)" .
```

### Quick Validation

Once the image is built, you can test like so:

```bash
docker run \
  --rm \
  -p 127.0.0.1:8080:8080 \
  -it jnsgruk/traefik \
  --api.dashboard=true --api.insecure=true --log.level=DEBUG
```

You should then be able to visit
[http://localhost:8080/dashboard/](http://localhost:8080/dashboard/).
