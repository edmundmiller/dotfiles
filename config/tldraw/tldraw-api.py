#!/usr/bin/env -S uv run --script
# /// script
# dependencies = []
# ///
"""Call tldraw offline's loopback agent API without exposing its launch token."""

import argparse
import http.client
import json
import os
from pathlib import Path
import sys


def tldraw_server_path():
    """Locate tldraw's per-launch discovery file, not a persistent credential."""
    if sys.platform == "darwin":
        return Path.home() / "Library/Application Support/tldraw/server.json"
    return (
        Path(os.environ.get("XDG_CONFIG_HOME", Path.home() / ".config"))
        / "tldraw/server.json"
    )


def main():
    """Send one request; failed requests are never retried because they may edit a canvas."""
    parser = argparse.ArgumentParser(
        description="Call the running tldraw offline app's local agent API. Open the app first.",
        epilog="Example: tldraw-api POST /api/search 'return await api.getDocs()'",
    )
    parser.add_argument("method", choices=["GET", "POST", "DELETE"])
    parser.add_argument("path", help="Local API path, e.g. /readme or /api/search")
    parser.add_argument(
        "body", nargs="?", help="JSON or JavaScript; use - to read stdin"
    )
    parser.add_argument("--server-file", type=Path, default=tldraw_server_path())
    parser.add_argument(
        "--timeout",
        type=float,
        default=30,
        help="Request timeout in seconds (default: 30)",
    )
    args = parser.parse_args()
    if not args.path.startswith("/") or args.path.startswith("//"):
        parser.error("path must be a local absolute path, not a URL")
    if args.timeout <= 0:
        parser.error("timeout must be positive")

    try:
        server = json.loads(args.server_file.read_text(encoding="utf-8"))
        port, token = server["port"], server["token"]
        if (
            type(port) is not int
            or not 1 <= port <= 65535
            or not isinstance(token, str)
            or not token
        ):
            raise ValueError("invalid discovery fields")
    except (OSError, ValueError, KeyError, TypeError):
        print(
            "tldraw-api: discovery file missing or invalid; open tldraw offline first",
            file=sys.stderr,
        )
        return 1

    body = sys.stdin.read() if args.body == "-" else args.body
    headers = {"Authorization": f"Bearer {token}"}
    if body is not None:
        headers["Content-Type"] = (
            "application/json" if body.lstrip().startswith("{") else "text/plain"
        )
    # No proxies, remote hosts, redirects, or token-bearing shell arguments.
    connection = http.client.HTTPConnection("127.0.0.1", port, timeout=args.timeout)
    try:
        connection.request(
            args.method,
            args.path,
            body.encode("utf-8") if body is not None else None,
            headers,
        )
        response = connection.getresponse()
        result = response.read()
    except (OSError, ValueError, http.client.HTTPException):
        print(
            "tldraw-api: local request failed; check the app is running (do not blindly retry edits)",
            file=sys.stderr,
        )
        return 1
    finally:
        connection.close()

    sys.stdout.buffer.write(result)
    if not 200 <= response.status < 300:
        print(
            f"tldraw-api: HTTP {response.status}; inspect the response before retrying",
            file=sys.stderr,
        )
        return 1
    try:
        payload = json.loads(result)
    except (ValueError, UnicodeError):
        return 0
    if isinstance(payload, dict) and payload.get("success") is False:
        print(
            "tldraw-api: operation failed; inspect the response before retrying",
            file=sys.stderr,
        )
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
