"""Exercise deployment reloads against HA's HTTP service contract."""

import importlib.util
import json
import tempfile
import sys
import threading
import unittest
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.error import HTTPError


source = (
    Path(sys.argv.pop(1))
    if len(sys.argv) > 1
    else Path(__file__).resolve().parents[1] / "reload-config.py"
)
spec = importlib.util.spec_from_file_location("reload_config", source)
reload_config = importlib.util.module_from_spec(spec)
spec.loader.exec_module(reload_config)


class ReloadTest(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        self.state = Path(temporary.name) / "state.json"
        self.calls = []
        self.valid = True
        self.fail = None
        owner = self

        class Handler(BaseHTTPRequestHandler):
            def do_POST(self):
                owner.assertEqual(self.headers["Authorization"], "Bearer fixture-token")
                owner.assertEqual(
                    self.rfile.read(int(self.headers["Content-Length"])), b"{}"
                )
                owner.calls.append(self.path)
                if self.path == owner.fail:
                    self.send_error(503)
                    return
                if self.path == "/api/config/core/check_config":
                    result = {"result": "valid" if owner.valid else "invalid"}
                else:
                    result = []
                data = json.dumps(result).encode()
                self.send_response(200)
                self.send_header("Content-Length", str(len(data)))
                self.end_headers()
                self.wfile.write(data)

            def log_message(self, *_args):
                pass

        self.server = ThreadingHTTPServer(("127.0.0.1", 0), Handler)
        thread = threading.Thread(target=self.server.serve_forever, daemon=True)
        thread.start()
        self.addCleanup(self.server.server_close)
        self.addCleanup(self.server.shutdown)
        self.url = f"http://127.0.0.1:{self.server.server_port}"
        self.manifest = {
            "version": 1,
            "domains": {"automation": "a" * 64, "script": "b" * 64, "scene": "c" * 64},
        }

    def apply(self):
        return reload_config.reload_configuration(
            self.manifest, self.state, "fixture-token", self.url
        )

    def test_only_changed_domains_reload_and_no_change_sends_nothing(self):
        self.assertEqual(self.apply(), ["automation", "script", "scene"])
        self.assertEqual(
            self.calls,
            [
                "/api/config/core/check_config",
                "/api/services/automation/reload",
                "/api/services/script/reload",
                "/api/services/scene/reload",
            ],
        )
        self.calls.clear()
        self.assertEqual(self.apply(), [])
        self.assertEqual(self.calls, [])
        self.manifest["domains"]["script"] = "d" * 64
        self.assertEqual(self.apply(), ["script"])
        self.assertEqual(
            self.calls, ["/api/config/core/check_config", "/api/services/script/reload"]
        )
        self.assertNotIn("pending", json.loads(self.state.read_text()))

    def test_removed_domain_reloads_but_absent_domain_does_not(self):
        self.manifest["domains"]["scene"] = None
        self.assertEqual(self.apply(), ["automation", "script"])
        self.manifest["domains"]["script"] = None
        self.assertEqual(self.apply(), ["script"])

    def test_invalid_config_or_manifest_never_calls_a_reload(self):
        self.valid = False
        with self.assertRaises(ValueError):
            self.apply()
        self.assertEqual(self.calls, ["/api/config/core/check_config"])
        self.assertFalse(self.state.exists())
        self.calls.clear()
        self.manifest["domains"]["homeassistant"] = "e" * 64
        with self.assertRaises(ValueError):
            self.apply()
        self.assertEqual(self.calls, [])

    def test_failed_write_is_reserved_and_never_automatically_replayed(self):
        self.fail = "/api/services/script/reload"
        with self.assertRaises(HTTPError):
            self.apply()
        state = json.loads(self.state.read_text())
        self.assertEqual(
            state, {"applied": {"automation": "a" * 64}, "pending": "script"}
        )
        calls = list(self.calls)
        # Even a new desired revision does not authorize replaying an uncertain write.
        self.manifest["domains"]["script"] = "d" * 64
        with self.assertRaisesRegex(ValueError, "uncertain"):
            self.apply()
        self.assertEqual(self.calls, calls)
        self.assertEqual(json.loads(self.state.read_text()), state)


if __name__ == "__main__":
    unittest.main()
