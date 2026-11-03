"""Exercise the CLI against a real loopback HTTP server, without launching the GUI."""

import http.server
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import threading
import unittest


ROOT = Path(__file__).resolve().parents[1]
CLI = ROOT / "config/tldraw/tldraw-api.py"


class TldrawApiTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.home = Path(self.temp.name)
        self.discovery = self.home / "server.json"
        self.requests = []
        self.status = 200
        self.response = b'{"success":true,"result":[{"id":"doc:one"}]}'
        case = self

        class Handler(http.server.BaseHTTPRequestHandler):
            def do_POST(self):
                body = self.rfile.read(int(self.headers.get("Content-Length", 0)))
                case.requests.append(
                    (self.command, self.path, dict(self.headers), body)
                )
                self.send_response(case.status)
                self.send_header("Location", "/should-not-follow")
                self.end_headers()
                self.wfile.write(case.response)

            do_GET = do_POST
            do_DELETE = do_POST

            def log_message(self, *_):
                pass

        self.server = http.server.HTTPServer(("127.0.0.1", 0), Handler)
        self.addCleanup(self.server.server_close)
        thread = threading.Thread(target=self.server.serve_forever, daemon=True)
        thread.start()
        self.addCleanup(thread.join)
        self.addCleanup(self.server.shutdown)
        self.write_discovery("first-launch-secret")

    def write_discovery(self, token):
        self.discovery.write_text(
            json.dumps({"port": self.server.server_port, "token": token})
        )

    def call_cli(self, *args, stdin=None, discovery=True):
        command = [sys.executable, str(CLI)]
        if discovery:
            command += ["--server-file", str(self.discovery)]
        return subprocess.run(
            command + list(args),
            input=stdin,
            text=True,
            capture_output=True,
            timeout=5,
            env={**os.environ, "HOME": str(self.home)},
        )

    def test_raw_javascript_uses_discovery_and_utf8_without_leaking_token(self):
        result = self.call_cli("POST", "/api/search", 'return "caf\u00e9"')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(json.loads(result.stdout)["result"], [{"id": "doc:one"}])
        method, path, headers, body = self.requests[0]
        self.assertEqual((method, path), ("POST", "/api/search"))
        self.assertEqual(body, 'return "caf\u00e9"'.encode())
        self.assertEqual(headers["Content-Type"], "text/plain")
        self.assertEqual(headers["Authorization"], "Bearer first-launch-secret")
        self.assertNotIn("first-launch-secret", result.stdout + result.stderr)

    def test_stdin_json_and_refreshed_launch_token(self):
        self.write_discovery("second-launch-secret")
        result = self.call_cli(
            "POST", "/api/docs/create", "-", stdin=' {"name":"Planning"}'
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        _, path, headers, body = self.requests[0]
        self.assertEqual(path, "/api/docs/create")
        self.assertEqual(json.loads(body), {"name": "Planning"})
        self.assertEqual(headers["Content-Type"], "application/json")
        self.assertEqual(headers["Authorization"], "Bearer second-launch-secret")

    def test_default_discovery_path(self):
        if sys.platform == "darwin":
            default_path = self.home / "Library/Application Support/tldraw/server.json"
        else:
            default_path = self.home / ".config/tldraw/server.json"
        default_path.parent.mkdir(parents=True)
        default_path.write_bytes(self.discovery.read_bytes())
        # Isolate XDG_CONFIG_HOME too, in case the runner sets it.
        previous = os.environ.pop("XDG_CONFIG_HOME", None)
        try:
            result = self.call_cli("GET", "/readme", discovery=False)
        finally:
            if previous is not None:
                os.environ["XDG_CONFIG_HOME"] = previous
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.requests[0][:2], ("GET", "/readme"))

    def test_plain_text_readme(self):
        self.response = b"# API reference\n"
        result = self.call_cli("GET", "/readme")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout, "# API reference\n")

    def test_http_failures_and_redirects_are_not_retried(self):
        for status in (401, 409, 500, 302):
            with self.subTest(status=status):
                self.requests.clear()
                self.status = status
                self.response = b'{"error":"request rejected"}'
                result = self.call_cli(
                    "POST", "/api/doc/one/exec", "editor.deleteShapes([])"
                )
                self.assertEqual(result.returncode, 1)
                self.assertIn(f"HTTP {status}", result.stderr)
                self.assertEqual(
                    json.loads(result.stdout), {"error": "request rejected"}
                )
                self.assertEqual(len(self.requests), 1)
                self.assertNotIn("first-launch-secret", result.stdout + result.stderr)

    def test_api_failure_on_http_200_exits_nonzero(self):
        self.response = b'{"success":false,"error":"Unknown shape"}'
        result = self.call_cli("POST", "/api/doc/one/exec", "return badShape")
        self.assertEqual(result.returncode, 1)
        self.assertIn("operation failed", result.stderr)
        self.assertEqual(json.loads(result.stdout)["error"], "Unknown shape")
        self.assertEqual(len(self.requests), 1)

    def test_missing_and_invalid_discovery_send_no_request(self):
        for content in (
            None,
            "not json",
            "[]",
            '{"port":7236}',
            '{"port":true,"token":"x"}',
        ):
            with self.subTest(content=content):
                if content is None:
                    self.discovery.unlink()
                else:
                    self.discovery.write_text(content)
                result = self.call_cli("GET", "/readme")
                self.assertEqual(result.returncode, 1)
                self.assertIn("open tldraw offline", result.stderr)
                self.assertEqual(result.stdout, "")
                self.assertEqual(self.requests, [])

    def test_remote_urls_are_rejected_without_sending_credentials(self):
        for path in ("https://example.com/api", "//example.com/api"):
            with self.subTest(path=path):
                result = self.call_cli("GET", path)
                self.assertEqual(result.returncode, 2)
                self.assertIn("not a URL", result.stderr)
                self.assertEqual(self.requests, [])

    def test_stale_discovery_reports_connection_failure(self):
        self.server.shutdown()
        self.server.server_close()
        result = self.call_cli("GET", "/readme", "--timeout", "0.2")
        self.assertEqual(result.returncode, 1)
        self.assertIn("check the app is running", result.stderr)
        self.assertNotIn("first-launch-secret", result.stdout + result.stderr)
        self.assertEqual(self.requests, [])


if __name__ == "__main__":
    unittest.main()
