from __future__ import annotations

import base64
import json
import os
from pathlib import Path
import struct
import subprocess
import sys
import tempfile
import threading
import unittest
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import parse_qs, urlsplit
import zlib


SCRIPT = Path(__file__).with_name("displayctl")
FIXTURES = Path(__file__).with_name("fixtures") / "macos"


class MockDisplayHandler(BaseHTTPRequestHandler):
    requests: list[tuple[str, str, bytes]] = []
    last_headers: dict[str, str] = {}
    error_status: int | None = None
    error_body: bytes = b""
    screen_body: bytes = b""
    screen_bodies: dict[int, bytes] = {}

    def log_message(self, _format: str, *_args: object) -> None:
        return

    def _record(self, body: bytes = b"") -> None:
        self.__class__.requests.append((self.command, self.path, body))
        self.__class__.last_headers = dict(self.headers.items())

    def do_GET(self) -> None:  # noqa: N802
        self._record()
        if urlsplit(self.path).path == "/api/screen":
            display = int(parse_qs(urlsplit(self.path).query).get("display", ["0"])[0])
            self.send_response(200)
            self.send_header("Content-Type", "image/bmp")
            self.end_headers()
            self.wfile.write(self.__class__.screen_bodies.get(display, self.__class__.screen_body))
            return
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.end_headers()
        self.wfile.write(b'{"ok":true}')

    def do_POST(self) -> None:  # noqa: N802
        length = int(self.headers.get("Content-Length", "0"))
        body = self.rfile.read(length)
        self._record(body)
        if self.__class__.error_status is not None:
            self.send_response(self.__class__.error_status)
            self.send_header("Content-Type", "application/json")
            self.end_headers()
            self.wfile.write(self.__class__.error_body)
            return
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.end_headers()
        self.wfile.write(b'{"ok":true}')

    def do_DELETE(self) -> None:  # noqa: N802
        self._record()
        if self.__class__.error_status is not None:
            self.send_response(self.__class__.error_status)
            self.send_header("Content-Type", "application/json")
            self.end_headers()
            self.wfile.write(self.__class__.error_body)
            return
        self.send_response(204)
        self.end_headers()


class DisplayctlContractTest(unittest.TestCase):
    def setUp(self) -> None:
        MockDisplayHandler.requests = []
        MockDisplayHandler.last_headers = {}
        MockDisplayHandler.error_status = None
        MockDisplayHandler.error_body = b""
        MockDisplayHandler.screen_bodies = {}
        raw_frame = (bytes(range(256)) * ((72 * 16 * 3 + 255) // 256))[: 72 * 16 * 3]
        MockDisplayHandler.screen_body = base64.b64encode(raw_frame)
        self.server = ThreadingHTTPServer(("127.0.0.1", 0), MockDisplayHandler)
        self.thread = threading.Thread(target=self.server.serve_forever, daemon=True)
        self.thread.start()
        self.base_url = f"http://127.0.0.1:{self.server.server_port}"
        self.tempdir = tempfile.TemporaryDirectory()
        self.root = Path(self.tempdir.name)
        self.config = self.root / "config.json"
        self.config.write_text(
            json.dumps(
                {
                    "version": 1,
                    "aliases": {
                        "busy-bar": {
                            "kind": "busy",
                            "targets": {
                                "usb": {"base_url": self.base_url},
                                "lan": {
                                    "base_url": self.base_url,
                                    "token_env": "BUSY_BAR_API_TOKEN",
                                    "token_required": False,
                                },
                            },
                        },
                        "trmnl-og": {
                            "kind": "trmnl",
                            "model": "og_png",
                            "api_base_url": self.base_url,
                            "webhook_env": "TRMNL_AGENT_MESSAGE_WEBHOOK_URL",
                            "api_token_env": "TRMNL_API_KEY",
                            "device_token_env": "TRMNL_OG_DEVICE_API_KEY",
                        },
                    },
                }
            )
        )

    def tearDown(self) -> None:
        self.server.shutdown()
        self.server.server_close()
        self.tempdir.cleanup()

    def run_cli(self, *args: str, env: dict[str, str] | None = None) -> subprocess.CompletedProcess[str]:
        child_env = os.environ.copy()
        child_env.update(env or {})
        return subprocess.run(
            [sys.executable, str(SCRIPT), "--config", str(self.config), *args],
            text=True,
            capture_output=True,
            env=child_env,
            check=False,
        )

    def run_cli_default_config(
        self, *args: str, env: dict[str, str] | None = None
    ) -> subprocess.CompletedProcess[str]:
        child_env = os.environ.copy()
        child_env.update(env or {})
        if not env or "DISPLAYCTL_CONFIG" not in env:
            child_env.pop("DISPLAYCTL_CONFIG", None)
        return subprocess.run(
            [sys.executable, str(SCRIPT), *args],
            text=True,
            capture_output=True,
            env=child_env,
            check=False,
        )

    def write_manifest(self, payload: dict[str, object]) -> Path:
        path = self.root / "manifest.json"
        path.write_text(json.dumps(payload))
        return path

    def fixture_command(self, name: str, fixture: Path) -> Path:
        path = self.root / name
        path.write_text(
            f"#!{sys.executable}\n"
            "from pathlib import Path\n"
            f"print(Path({str(fixture)!r}).read_text(), end='')\n"
        )
        path.chmod(0o755)
        return path

    @unittest.expectedFailure
    def test_macos_status_reports_observed_ts5_link_training_failure(self) -> None:
        ioreg = self.fixture_command("ioreg", FIXTURES / "ts5-port-1-link-failure.ioreg")
        system_profiler = self.fixture_command("system_profiler", FIXTURES / "ts5-port-1.json")

        result = self.run_cli(
            "macos",
            "status",
            env={
                "DISPLAYCTL_IOREG_BIN": str(ioreg),
                "DISPLAYCTL_SYSTEM_PROFILER_BIN": str(system_profiler),
            },
        )

        self.assertEqual(result.returncode, 1, result.stderr)
        output = json.loads(result.stdout)
        self.assertFalse(output["ok"])
        self.assertEqual(output["dock"]["model"], "TS5")
        self.assertEqual(output["dock"]["host_port"], 1)
        self.assertEqual(output["dock"]["expected_host_port"], 2)
        self.assertEqual(
            {issue["code"] for issue in output["issues"]},
            {"display_link_training_failed", "ts5_host_port_mismatch"},
        )
        by_transport = {path["transport"]: path for path in output["display_paths"]}
        self.assertEqual(by_transport["Port-USB-C@1/CIO/DisplayPort@0"]["state"], "linked")
        self.assertEqual(by_transport["Port-USB-C@1/CIO/DisplayPort@1"]["state"], "link_training_failed")

    def test_inventory_exposes_public_alias_metadata_without_secret_values(self) -> None:
        result = self.run_cli("inventory", "--json")
        self.assertEqual(result.returncode, 0, result.stderr)
        output = json.loads(result.stdout)
        self.assertEqual(output["aliases"]["trmnl-og"]["model"], "og_png")
        self.assertIs(output["aliases"]["busy-bar"]["targets"]["lan"]["token_required"], False)
        self.assertNotIn("secret_ref", result.stdout)
        self.assertNotIn("op://Private/TRMNL/webhook", result.stdout)

    def test_default_config_resolution_prefers_env_then_user_then_source(self) -> None:
        home = self.root / "home"
        user_config = home / ".config" / "displayctl" / "config.json"
        user_config.parent.mkdir(parents=True)
        user_config.write_text(json.dumps({"version": 1, "aliases": {"user": {"kind": "test"}}}))
        env_config = self.root / "env-config.json"
        env_config.write_text(json.dumps({"version": 1, "aliases": {"env": {"kind": "test"}}}))

        user_result = self.run_cli_default_config("inventory", "--json", env={"HOME": str(home)})
        self.assertEqual(user_result.returncode, 0, user_result.stderr)
        self.assertEqual(set(json.loads(user_result.stdout)["aliases"]), {"user"})

        env_result = self.run_cli_default_config(
            "inventory",
            "--json",
            env={"HOME": str(home), "DISPLAYCTL_CONFIG": str(env_config)},
        )
        self.assertEqual(env_result.returncode, 0, env_result.stderr)
        self.assertEqual(set(json.loads(env_result.stdout)["aliases"]), {"env"})

        user_config.unlink()
        source_result = self.run_cli_default_config("inventory", "--json", env={"HOME": str(home)})
        self.assertEqual(source_result.returncode, 0, source_result.stderr)
        self.assertIn("busy-bar", json.loads(source_result.stdout)["aliases"])

    def test_dry_run_does_not_post(self) -> None:
        manifest = self.write_manifest(
            {
                "application_name": "agent_message",
                "priority": 40,
                "elements": [{"id": "message", "type": "text", "x": 2, "y": 2, "text": "hello", "timeout": 75, "font": "normal"}],
            }
        )
        result = self.run_cli("busy", "draw", "--manifest", str(manifest))
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertFalse(MockDisplayHandler.requests)
        self.assertFalse(json.loads(result.stdout)["applied"])

    def test_malformed_manifest_fails_before_http(self) -> None:
        manifest = self.write_manifest({"priority": 40, "elements": []})
        result = self.run_cli("busy", "validate", "--manifest", str(manifest))
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("application_name", result.stderr)
        self.assertFalse(MockDisplayHandler.requests)

    def test_busy_application_name_accepts_openapi_safe_pattern(self) -> None:
        manifest = self.write_manifest(
            {
                "application_name": "agent_message-1.v2",
                "priority": 50,
                "elements": [{"id": "message", "type": "text", "text": "hello", "timeout": 1, "font": "normal"}],
            }
        )
        result = self.run_cli("busy", "validate", "--manifest", str(manifest))
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertTrue(json.loads(result.stdout)["valid"])

    def test_busy_application_name_rejects_unsafe_pattern(self) -> None:
        manifest = self.write_manifest(
            {
                "application_name": "agent message",
                "priority": 40,
                "elements": [{"id": "message", "type": "text", "text": "hello", "timeout": 75, "font": "normal"}],
            }
        )
        result = self.run_cli("busy", "validate", "--manifest", str(manifest))
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("application_name", result.stderr)

    def test_busy_priority_above_agent_ceiling_is_rejected(self) -> None:
        manifest = self.write_manifest(
            {
                "application_name": "agent_message",
                "priority": 51,
                "elements": [{"id": "message", "type": "text", "text": "hello", "timeout": 75, "font": "normal"}],
            }
        )
        result = self.run_cli("busy", "validate", "--manifest", str(manifest))
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("priority", result.stderr)

    def test_busy_element_timeout_is_required_and_positive(self) -> None:
        for timeout in (None, 0):
            with self.subTest(timeout=timeout):
                element: dict[str, object] = {
                    "id": "message",
                    "type": "text",
                    "text": "hello",
                    "font": "normal",
                }
                if timeout is not None:
                    element["timeout"] = timeout
                manifest = self.write_manifest(
                    {
                        "application_name": "agent_message",
                        "priority": 40,
                        "elements": [element],
                    }
                )
                result = self.run_cli("busy", "validate", "--manifest", str(manifest))
                self.assertNotEqual(result.returncode, 0)
                self.assertIn("timeout", result.stderr)

    def test_busy_element_timeout_has_bounded_agent_policy(self) -> None:
        valid = self.write_manifest(
            {
                "application_name": "agent_message",
                "priority": 40,
                "elements": [
                    {
                        "id": "message",
                        "type": "text",
                        "text": "hello",
                        "font": "normal",
                        "timeout": 3_600,
                    }
                ],
            }
        )
        result = self.run_cli("busy", "validate", "--manifest", str(valid))
        self.assertEqual(result.returncode, 0, result.stderr)

        too_large = self.write_manifest(
            {
                "application_name": "agent_message",
                "priority": 40,
                "elements": [
                    {
                        "id": "message",
                        "type": "text",
                        "text": "hello",
                        "font": "normal",
                        "timeout": 3_601,
                    }
                ],
            }
        )
        result = self.run_cli("busy", "validate", "--manifest", str(too_large))
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("timeout", result.stderr)

    def test_busy_element_id_is_required_and_uses_safe_pattern(self) -> None:
        for element_id in (None, "message id"):
            with self.subTest(element_id=element_id):
                element: dict[str, object] = {
                    "type": "text",
                    "text": "hello",
                    "font": "normal",
                    "timeout": 75,
                }
                if element_id is not None:
                    element["id"] = element_id
                manifest = self.write_manifest(
                    {"application_name": "agent_message", "priority": 40, "elements": [element]}
                )
                result = self.run_cli("busy", "validate", "--manifest", str(manifest))
                self.assertNotEqual(result.returncode, 0)
                self.assertIn("id", result.stderr)

    def test_busy_text_requires_font(self) -> None:
        manifest = self.write_manifest(
            {
                "application_name": "agent_message",
                "priority": 40,
                "elements": [{"id": "message", "type": "text", "text": "hello", "timeout": 75}],
            }
        )
        result = self.run_cli("busy", "validate", "--manifest", str(manifest))
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("font", result.stderr)

    def test_busy_countdown_accepts_openapi_fields(self) -> None:
        manifest = self.write_manifest(
            {
                "application_name": "agent_message",
                "priority": 40,
                "elements": [
                    {
                        "id": "countdown",
                        "type": "countdown",
                        "timestamp": "1766620800",
                        "direction": "time_left",
                        "show_hours": "when_non_zero",
                        "timeout": 75,
                    }
                ],
            }
        )
        result = self.run_cli("busy", "validate", "--manifest", str(manifest))
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_busy_countdown_rejects_invalid_openapi_fields(self) -> None:
        base = {
            "id": "countdown",
            "type": "countdown",
            "timestamp": "1766620800",
            "direction": "time_left",
            "show_hours": "when_non_zero",
            "timeout": 75,
        }
        for field, value in (("timestamp", "1766x"), ("direction", "until"), ("show_hours", "never")):
            with self.subTest(field=field):
                element = dict(base)
                element[field] = value
                manifest = self.write_manifest(
                    {"application_name": "agent_message", "priority": 40, "elements": [element]}
                )
                result = self.run_cli("busy", "validate", "--manifest", str(manifest))
                self.assertNotEqual(result.returncode, 0)
                self.assertIn(field, result.stderr)

    def test_busy_rectangle_requires_positive_dimensions(self) -> None:
        valid = self.write_manifest(
            {
                "application_name": "agent_message",
                "priority": 40,
                "elements": [{"id": "box", "type": "rectangle", "width": 1, "height": 1, "timeout": 75}],
            }
        )
        result = self.run_cli("busy", "validate", "--manifest", str(valid))
        self.assertEqual(result.returncode, 0, result.stderr)
        for width, height in ((0, 1), (1, 0), (-1, 1)):
            with self.subTest(width=width, height=height):
                manifest = self.write_manifest(
                    {
                        "application_name": "agent_message",
                        "priority": 40,
                        "elements": [
                            {
                                "id": "box",
                                "type": "rectangle",
                                "width": width,
                                "height": height,
                                "timeout": 75,
                            }
                        ],
                    }
                )
                result = self.run_cli("busy", "validate", "--manifest", str(manifest))
                self.assertNotEqual(result.returncode, 0)
                self.assertIn("width", result.stderr) if width <= 0 else self.assertIn("height", result.stderr)

    def test_busy_image_and_animation_require_one_source(self) -> None:
        for element_type, source in (("image", "path"), ("animation", "stock_path")):
            valid_element: dict[str, object] = {
                "id": element_type,
                "type": element_type,
                "timeout": 75,
                source: "asset-name",
            }
            valid = self.write_manifest(
                {"application_name": "agent_message", "priority": 40, "elements": [valid_element]}
            )
            result = self.run_cli("busy", "validate", "--manifest", str(valid))
            self.assertEqual(result.returncode, 0, result.stderr)
            for sources in ({}, {"path": "a", "stock_path": "b"}):
                with self.subTest(element_type=element_type, sources=sources):
                    element = {
                        "id": element_type,
                        "type": element_type,
                        "timeout": 75,
                        **sources,
                    }
                    manifest = self.write_manifest(
                        {"application_name": "agent_message", "priority": 40, "elements": [element]}
                    )
                    result = self.run_cli("busy", "validate", "--manifest", str(manifest))
                    self.assertNotEqual(result.returncode, 0)
                    self.assertIn("path", result.stderr)

    def test_http_error_includes_bounded_safe_response_detail(self) -> None:
        MockDisplayHandler.error_status = 400
        MockDisplayHandler.error_body = json.dumps(
            {
                "error": "invalid draw",
                "token": "wire-secret",
                "detail": "x" * 1200,
                "url": f"{self.base_url}/api/display/draw?application_name=agent_message",
            }
        ).encode()
        result = self.run_cli(
            "busy",
            "clear",
            "--application",
            "agent_message",
            "--apply",
            env={"BUSY_BAR_API_TOKEN": "env-secret"},
        )
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("HTTP 400", result.stderr)
        self.assertIn("invalid draw", result.stderr)
        self.assertLess(len(result.stderr), 700)
        self.assertNotIn("wire-secret", result.stderr)
        self.assertNotIn("env-secret", result.stderr)
        self.assertNotIn("application_name=", result.stderr)

    def test_explicit_write_posts(self) -> None:
        manifest = self.write_manifest(
            {
                "application_name": "agent_message",
                "priority": 40,
                "elements": [{"id": "message", "type": "text", "x": 2, "y": 2, "text": "hello", "timeout": 75, "font": "normal"}],
            }
        )
        result = self.run_cli("busy", "draw", "--manifest", str(manifest), "--apply")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(MockDisplayHandler.requests[0][0], "POST")
        self.assertEqual(urlsplit(MockDisplayHandler.requests[0][1]).path, "/api/display/draw")
        self.assertTrue(json.loads(result.stdout)["applied"])

    def test_optional_busy_token_is_used_when_present_but_not_required(self) -> None:
        config = json.loads(self.config.read_text())
        config["aliases"]["busy-bar"]["targets"]["lan"]["token_required"] = False
        self.config.write_text(json.dumps(config))

        without_token = self.run_cli(
            "busy",
            "clear",
            "--target",
            "lan",
            "--application",
            "agent_message",
            "--apply",
        )
        self.assertEqual(without_token.returncode, 0, without_token.stderr)
        self.assertNotIn("X-API-Token", MockDisplayHandler.last_headers)

        with_token = self.run_cli(
            "busy",
            "clear",
            "--target",
            "lan",
            "--application",
            "agent_message",
            "--apply",
            env={"BUSY_BAR_API_TOKEN": "env-secret"},
        )
        self.assertEqual(with_token.returncode, 0, with_token.stderr)
        headers = {name.lower(): value for name, value in MockDisplayHandler.last_headers.items()}
        self.assertEqual(headers["x-api-token"], "env-secret")

    def test_busy_message_defaults_to_bounded_timeout(self) -> None:
        result = self.run_cli("busy", "message", "--text", "hello")
        self.assertEqual(result.returncode, 0, result.stderr)
        request = json.loads(result.stdout)["request"]
        self.assertEqual(request["priority"], 40)
        self.assertEqual(request["elements"][0]["timeout"], 75)

    def test_busy_message_rejects_nonpositive_timeout(self) -> None:
        result = self.run_cli("busy", "message", "--text", "hello", "--timeout", "0")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("timeout", result.stderr)
        self.assertFalse(MockDisplayHandler.requests)

    def test_busy_message_rejects_timeout_above_agent_policy(self) -> None:
        result = self.run_cli("busy", "message", "--text", "hello", "--timeout", "3601")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("timeout", result.stderr)
        self.assertFalse(MockDisplayHandler.requests)

    def test_clear_is_scoped_to_application_name(self) -> None:
        result = self.run_cli("busy", "clear", "--application", "agent_message", "--apply")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(MockDisplayHandler.requests[0][0], "DELETE")
        self.assertIn("application_name=agent_message", MockDisplayHandler.requests[0][1])

    def test_capture_writes_valid_png(self) -> None:
        output = self.root / "capture.png"
        result = self.run_cli("busy", "capture", "--output", str(output))
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(output.read_bytes()[:8], b"\x89PNG\r\n\x1a\n")
        self.assertEqual(struct.unpack(">II", output.read_bytes()[16:24]), (72, 16))

    def png_rgb_bytes(self, path: Path) -> bytes:
        data = path.read_bytes()
        offset = 8
        compressed = bytearray()
        while offset < len(data):
            length = struct.unpack(">I", data[offset : offset + 4])[0]
            kind = data[offset + 4 : offset + 8]
            chunk = data[offset + 8 : offset + 8 + length]
            if kind == b"IDAT":
                compressed.extend(chunk)
            offset += 12 + length
        rows = zlib.decompress(bytes(compressed))
        self.assertEqual(rows[0], 0)
        return rows[1:]

    def test_capture_converts_busy_front_bgr_to_png_rgb(self) -> None:
        wire = bytearray(72 * 16 * 3)
        wire[0:6] = bytes((0, 0, 255, 255, 0, 0))  # red, then blue in BGR888
        MockDisplayHandler.screen_bodies[0] = base64.b64encode(bytes(wire))
        output = self.root / "front-colors.png"
        result = self.run_cli("busy", "capture", "--display", "0", "--output", str(output))
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.png_rgb_bytes(output)[:6], bytes((255, 0, 0, 0, 0, 255)))

    def test_capture_unpacks_busy_back_l4_low_nibble_first(self) -> None:
        wire = bytes((0xE1,)) + bytes(160 * 80 // 2 - 1)
        MockDisplayHandler.screen_bodies[1] = base64.b64encode(wire)
        output = self.root / "back-grayscale.png"
        result = self.run_cli("busy", "capture", "--display", "1", "--output", str(output))
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.png_rgb_bytes(output)[:6], bytes((17, 17, 17, 238, 238, 238)))

    def test_trmnl_webhook_write_and_redaction(self) -> None:
        secret_url = f"{self.base_url}/webhook/secret-uuid-value"
        result = self.run_cli(
            "trmnl-og",
            "message",
            "--text",
            "hello",
            "--apply",
            env={"TRMNL_AGENT_MESSAGE_WEBHOOK_URL": secret_url},
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(MockDisplayHandler.requests[0][0], "POST")
        self.assertEqual(urlsplit(MockDisplayHandler.requests[0][1]).path, "/webhook/secret-uuid-value")
        self.assertNotIn("secret-uuid-value", result.stdout)
        self.assertNotIn("secret-uuid-value", result.stderr)
        self.assertEqual(json.loads(MockDisplayHandler.requests[0][2]), {"merge_variables": {"message": "hello"}})

    def test_trmnl_message_matches_full_template_payload(self) -> None:
        secret_url = f"{self.base_url}/webhook/secret-uuid-value"
        expected = {
            "headline": "Build complete",
            "message": "hello",
            "source": "Codex",
            "status": "Ready",
            "timestamp": "2026-08-24 09:30",
            "progress": 62,
        }
        result = self.run_cli(
            "trmnl-og",
            "message",
            "--text",
            expected["message"],
            "--headline",
            expected["headline"],
            "--source",
            expected["source"],
            "--status",
            expected["status"],
            "--timestamp",
            expected["timestamp"],
            "--progress",
            str(expected["progress"]),
            "--apply",
            env={"TRMNL_AGENT_MESSAGE_WEBHOOK_URL": secret_url},
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(json.loads(MockDisplayHandler.requests[0][2]), {"merge_variables": expected})
        self.assertEqual(json.loads(result.stdout)["payload"], expected)

    def test_trmnl_message_dry_run_contains_only_supplied_public_fields(self) -> None:
        result = self.run_cli(
            "trmnl-og",
            "message",
            "--text",
            "hello",
            "--status",
            "Working",
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertFalse(MockDisplayHandler.requests)
        self.assertEqual(
            json.loads(result.stdout)["payload"],
            {"message": "hello", "status": "Working"},
        )

    def test_trmnl_message_rejects_progress_outside_range(self) -> None:
        result = self.run_cli(
            "trmnl-og",
            "message",
            "--text",
            "hello",
            "--progress",
            "101",
            "--apply",
            env={"TRMNL_AGENT_MESSAGE_WEBHOOK_URL": f"{self.base_url}/webhook/secret-uuid-value"},
        )
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("progress", result.stderr)
        self.assertFalse(MockDisplayHandler.requests)

    def test_trmnl_devices_uses_account_api_key_without_redacting_metadata(self) -> None:
        result = self.run_cli(
            "trmnl-og",
            "devices",
            env={"TRMNL_API_KEY": "user-account-secret"},
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(MockDisplayHandler.last_headers["Authorization"], "Bearer user-account-secret")
        self.assertNotIn("user-account-secret", result.stdout)

    def test_trmnl_current_uses_device_access_token(self) -> None:
        result = self.run_cli(
            "trmnl-og",
            "current",
            env={"TRMNL_OG_DEVICE_API_KEY": "device-secret"},
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(MockDisplayHandler.last_headers["Access-Token"], "device-secret")
        self.assertNotIn("device-secret", result.stdout)

    def test_doctor_reports_trmnl_capabilities_independently(self) -> None:
        result = self.run_cli("doctor", env={"TRMNL_API_KEY": "user-account-secret"})
        self.assertNotEqual(result.returncode, 0)
        checks = json.loads(result.stdout)["checks"]
        trmnl_checks = [check for check in checks if check["alias"] == "trmnl-og"]
        self.assertEqual(
            {check["capability"] for check in trmnl_checks},
            {"devices", "current", "message"},
        )
        by_capability = {check["capability"]: check for check in trmnl_checks}
        self.assertTrue(by_capability["devices"]["ok"])
        self.assertFalse(by_capability["current"]["ok"])
        self.assertFalse(by_capability["message"]["ok"])
        self.assertTrue(all(check.get("capability") for check in trmnl_checks))


if __name__ == "__main__":
    unittest.main()
