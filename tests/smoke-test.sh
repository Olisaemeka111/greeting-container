#!/usr/bin/env bash
# Smoke-test a built image the way Kubernetes would run it: non-root, read-only
# root filesystem, no Linux capabilities. Checks every endpoint, that PORT and
# GREETING are honoured, and that SIGTERM gives a clean shutdown.
#
# Usage: tests/smoke-test.sh <image>
set -euo pipefail

image="${1:?usage: $0 <image>}"
name="sample-app-smoke-$$"
host_port=18080
app_port=9090 # deliberately not the default, to prove PORT is honoured
greeting="hello from the smoke test"

fail() {
  echo "FAIL: $*" >&2
  docker logs "$name" >&2 || true
  exit 1
}
trap 'docker rm -f "$name" >/dev/null 2>&1 || true' EXIT

docker run -d --name "$name" \
  --read-only --cap-drop ALL --security-opt no-new-privileges \
  --health-interval 2s \
  -e GREETING="$greeting" -e PORT="$app_port" \
  -p "127.0.0.1:${host_port}:${app_port}" \
  "$image" >/dev/null

# Wait for the image's own HEALTHCHECK to pass.
status=starting
for _ in $(seq 1 30); do
  status="$(docker inspect -f '{{.State.Health.Status}}' "$name")"
  [ "$status" = healthy ] && break
  sleep 1
done
[ "$status" = healthy ] || fail "container never became healthy (status: $status)"

base="http://127.0.0.1:${host_port}"
[ "$(curl -fsS "$base/healthz" | jq -r .status)" = ok ] || fail "/healthz did not return ok"
[ "$(curl -fsS "$base/" | jq -r .message)" = "$greeting" ] || fail "/ did not return GREETING"
[ "$(curl -fsS "$base/info" | jq -r .port)" = "$app_port" ] || fail "/info did not report PORT"

[ "$(docker exec "$name" id -u)" != 0 ] || fail "container is running as root"

docker stop -t 10 "$name" >/dev/null
code="$(docker inspect -f '{{.State.ExitCode}}' "$name")"
[ "$code" = 0 ] || fail "unclean shutdown on SIGTERM (exit code $code)"

echo "PASS: $image"
