"""
Gunicorn settings for the container image.

Anything that may need tuning per environment is read from an environment
variable, so it can be changed in a Kubernetes manifest without a rebuild.
"""

import os

# Listen on the same PORT the app reports in /info (default 8080).
bind = f"0.0.0.0:{os.environ.get('PORT', '8080')}"

# WEB_CONCURRENCY is gunicorn's conventional override for the worker count.
workers = int(os.environ.get("WEB_CONCURRENCY", "2"))

# Worker heartbeat files go on tmpfs: avoids stalls on overlay filesystems and
# lets the container run with a read-only root filesystem.
worker_tmp_dir = "/dev/shm"

# Request logs to stdout (errors already go to stderr) for the runtime to collect.
accesslog = "-"

# Finish in-flight requests inside Kubernetes' default 30s termination grace period.
graceful_timeout = 25
