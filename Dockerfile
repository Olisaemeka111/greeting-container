# syntax=docker/dockerfile:1

# Slim base pinned by tag *and* digest so every build starts from identical bytes.
# Dependabot (.github/dependabot.yml) raises a PR when a patched digest is published.
FROM python:3.12.15-slim-trixie@sha256:05cda9777409a9c3ffddd94a4c476b79f0769a0b4857f0c7ed9226b6800b0d6f AS base

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PATH="/opt/venv/bin:${PATH}"

# ---- build: install dependencies into a self-contained virtualenv ----------
FROM base AS build

ENV PIP_DISABLE_PIP_VERSION_CHECK=1

RUN python -m venv /opt/venv

# Copy only the requirements first so this layer stays cached until they change.
# The cache mount speeds up rebuilds without leaving pip's cache in any layer.
COPY app/requirements.txt /tmp/requirements.txt
RUN --mount=type=cache,target=/root/.cache/pip \
    pip install -r /tmp/requirements.txt

# ---- runtime: only the virtualenv and the app, no compilers or tooling -----
FROM base AS runtime

LABEL org.opencontainers.image.title="sample-app" \
      org.opencontainers.image.description="Minimal Flask greeting service served by gunicorn" \
      org.opencontainers.image.source="https://github.com/Olisaemeka111/greeting-container" \
      org.opencontainers.image.licenses="MIT"

# Fixed numeric UID/GID so Kubernetes `runAsNonRoot` can verify the user.
RUN groupadd --system --gid 10001 app \
    && useradd --system --uid 10001 --gid app --no-create-home --shell /usr/sbin/nologin app

WORKDIR /app

COPY --from=build /opt/venv /opt/venv
# Files stay owned by root: the app user can read the code but not change it.
COPY app/app.py gunicorn.conf.py ./

ENV PORT=8080
EXPOSE 8080

USER 10001:10001

# Used by `docker run`; Kubernetes ignores this and uses its own probes on /healthz.
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD python -c "import os, urllib.request; urllib.request.urlopen('http://127.0.0.1:' + os.environ['PORT'] + '/healthz', timeout=2)" || exit 1

# Exec form: gunicorn is PID 1 and receives SIGTERM directly for a graceful shutdown.
CMD ["gunicorn", "--config", "gunicorn.conf.py", "app:app"]
