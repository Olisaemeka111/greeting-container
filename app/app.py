"""
Minimal sample web application for the DevOps interview task.

This app is intentionally simple. Candidates should NOT need to modify it.
It exposes:
  GET /          -> greeting message (reads GREETING from the environment)
  GET /healthz   -> liveness/readiness probe endpoint
  GET /info      -> basic runtime info (useful for verifying config injection)

The app listens on the port defined by the PORT environment variable
(default: 8080).
"""

import os
import socket

from flask import Flask, jsonify

app = Flask(__name__)

GREETING = os.environ.get("GREETING", "Hello from the sample app!")
PORT = int(os.environ.get("PORT", "8080"))


@app.route("/")
def index():
    return jsonify(
        message=GREETING,
        hostname=socket.gethostname(),
    )


@app.route("/healthz")
def healthz():
    return jsonify(status="ok"), 200


@app.route("/info")
def info():
    return jsonify(
        greeting=GREETING,
        port=PORT,
        hostname=socket.gethostname(),
    )


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=PORT)
