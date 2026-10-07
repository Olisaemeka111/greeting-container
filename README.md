# DevOps Interview Task (Part 1): Containerize

**This is a take-home task.** Please submit by the date given when the task was
issued.

## Overview

You are given a small web application (`app/`). A working `Dockerfile` is
provided, but it was written quickly and does **not** follow container best
practices. Your job is to refactor it into a production-quality image and push
it to a container registry.

You do **not** need to modify the application code.

## What we provide

Clone this repository into your local account.

> **Do Not** fork this repository. Clone it and re-push it into your local account.

The following is provided as part of this repository:

```text
Dockerfile            # a working but non-production Dockerfile — improve it
app/
  app.py              # a minimal Python Flask web app (do not modify)
  requirements.txt    # the app's dependencies (do not modify)
```

The application:

-   Listens on the port given by the `PORT` environment variable (default `8080`).
-   Reads a `GREETING` environment variable used in its response.
-   Exposes `GET /`, `GET /healthz`, and `GET /info`.

## Solution

Published image (public, `linux/amd64` and `linux/arm64`):
[`ghcr.io/olisaemeka111/sample-app:v1`](https://github.com/users/Olisaemeka111/packages/container/package/sample-app)

```shell
docker run --rm -p 8080:8080 -e GREETING="Hello, DWP" ghcr.io/olisaemeka111/sample-app:v1
curl localhost:8080/info
```

### Dockerfile changes

-   **Slim base image, pinned by tag and digest.** `python:3.12.15-slim-trixie` replaces the full
    `python:3.12` image, which carries compilers and hundreds of OS packages the app never uses.
-   **No build tools or editors.** `build-essential`, `gcc`, `curl` and `vim` are gone. Flask and
    gunicorn install as pure-Python wheels, so nothing needs compiling, and each tool was extra
    attack surface.
-   **Multi-stage build.** Dependencies are installed into a virtualenv in a `build` stage; the
    final stage copies in only that virtualenv and the application code.
-   **Cache-friendly layer order.** `requirements.txt` is copied and installed before the code, so a
    code change does not reinstall dependencies. A BuildKit cache mount speeds up dependency
    changes without leaving pip's cache in the image.
-   **`.dockerignore` allowlist.** The original `COPY . .` put `.git`, docs and the Dockerfile into
    the image and invalidated the cache on any change. Now only three files enter the build context.
-   **Runs as a non-root user** with a fixed numeric UID (`10001`), so Kubernetes `runAsNonRoot` can
    verify it. The code is owned by root, so the process cannot modify it.
-   **gunicorn configuration in [`gunicorn.conf.py`](gunicorn.conf.py).** The original command
    hard-coded port 8080, so setting `PORT` changed what `/info` reported but not the port gunicorn
    listened on. gunicorn now binds to `$PORT`. Workers are tunable with `WEB_CONCURRENCY`, request
    logs go to stdout, and worker heartbeat files go to `/dev/shm` so the image works with a
    read-only root filesystem.
-   **Graceful shutdown.** The exec-form `CMD` makes gunicorn PID 1, so it receives `SIGTERM`
    directly, and `graceful_timeout` (25s) finishes in-flight requests inside Kubernetes' default
    30s grace period.
-   **`HEALTHCHECK`** against `/healthz` for plain Docker. Kubernetes ignores it, so use probes there.
-   **OCI labels**, including `org.opencontainers.image.source`, which links the GHCR package to
    this repository.

### Supporting changes

-   **CI pipeline ([`.github/workflows/container.yml`](.github/workflows/container.yml))**, run on
    every push and pull request:
    1.  lints the Dockerfile with hadolint
    2.  builds the image and runs [`tests/smoke-test.sh`](tests/smoke-test.sh). The test starts the
        container as Kubernetes would (non-root, read-only root filesystem, all capabilities
        dropped), calls every endpoint, checks that `PORT` and `GREETING` are honoured, and checks
        for a clean exit on `SIGTERM`.
    3.  scans the image with Trivy and fails on any fixable HIGH or CRITICAL vulnerability
    4.  on a `v*` tag, pushes a multi-arch image to GHCR with an SBOM and build provenance

    All actions are pinned to commit SHAs, and the job token has only the permissions it needs.
-   **Dependabot ([`.github/dependabot.yml`](.github/dependabot.yml))** keeps the base-image digest
    and action SHAs patched, staying on Python 3.12.

### Configuration

| Variable          | Default                      | Purpose                    |
| ----------------- | ---------------------------- | -------------------------- |
| `GREETING`        | `Hello from the sample app!` | Message returned by `/`    |
| `PORT`            | `8080`                       | Port gunicorn listens on   |
| `WEB_CONCURRENCY` | `2`                          | Number of gunicorn workers |

### Notes for the Kubernetes stage

-   The image runs unchanged under a restricted security context: `runAsNonRoot: true`,
    `readOnlyRootFilesystem: true`, `allowPrivilegeEscalation: false`, `capabilities.drop: [ALL]`.
-   Point liveness and readiness probes at `GET /healthz` on port 8080.

### Not changed

-   `app/` is untouched, as the brief requires. Only the top-level Python dependencies are pinned,
    so transitive ones (Werkzeug, Jinja2 and so on) are resolved at build time. A hashed lock file
    installed with `pip install --require-hashes` would make builds fully reproducible. That needs
    the app's dependency file, so I would raise it with the app team.
