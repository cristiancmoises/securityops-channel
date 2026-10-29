#!/usr/bin/env python3
"""Recover the public Guix publisher when its local HTTP listener wedges."""

import http.client
import subprocess
import sys
import time
from urllib.error import HTTPError, URLError
from urllib.request import HTTPRedirectHandler, Request, build_opener

PUBLISH_URL = "http://127.0.0.1:8080/"
PUBLISH_UNIT = "guix-publish.service"
PRE_RESTART_ATTEMPTS = 2
POST_RESTART_ATTEMPTS = 20


class NoRedirects(HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        return None


def probe_local():
    request = Request(
        PUBLISH_URL,
        headers={"Accept": "text/html", "User-Agent": "securityops-publish-health/1"},
    )
    try:
        with build_opener(NoRedirects()).open(request, timeout=5) as response:
            return response.status == 200 and bool(response.read(1))
    except (
        HTTPError,
        URLError,
        TimeoutError,
        ConnectionError,
        http.client.HTTPException,
    ):
        return False


def restart_publish():
    subprocess.run(
        ["systemctl", "restart", PUBLISH_UNIT],
        check=True,
        timeout=30,
    )


def ensure_healthy(probe, restart, sleep=time.sleep):
    for attempt in range(PRE_RESTART_ATTEMPTS):
        if probe():
            return "healthy"
        if attempt + 1 < PRE_RESTART_ATTEMPTS:
            sleep(2)

    restart()
    for _ in range(POST_RESTART_ATTEMPTS):
        sleep(1)
        if probe():
            return "restarted"
    raise RuntimeError("guix publish did not recover after restart")


def main():
    try:
        result = ensure_healthy(probe_local, restart_publish)
    except (OSError, RuntimeError, subprocess.SubprocessError) as error:
        print(f"Guix publisher health check failed: {error}", file=sys.stderr)
        return 1
    print(f"Guix publisher health: {result}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
