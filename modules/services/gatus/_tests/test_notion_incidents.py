"""Exercise local queues against HTTP Notion and Family Ops fixtures, never live services."""

from contextlib import closing, redirect_stdout
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import importlib.util
import io
import hashlib
import json
import os
from pathlib import Path
import re
import shlex
import socket
import sqlite3
import subprocess
import sys
import tempfile
import threading
import time
import unittest
from unittest.mock import patch
from urllib.error import HTTPError, URLError
from urllib.request import Request, urlopen

source = Path(sys.argv.pop(1)) if len(sys.argv) > 1 else Path(__file__).parents[1] / "incident-delivery.py"
spec = importlib.util.spec_from_file_location("incidents", source)
incidents = importlib.util.module_from_spec(spec)
spec.loader.exec_module(incidents)
ENDPOINT = "Smart Home: Home Assistant Runtime"
EMAIL_INGEST = 'email"slash\\and&pipe|dollar$'


class IncidentTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.db = Path(self.tmp.name) / "incidents.sqlite"
        self.store = incidents.Incidents(self.db)
        self.pages = {}
        self.create_mode = "success"
        self.query_mode = "success"
        self.patch_mode = "success"
        self.creates = 0
        self.probe_ok = False
        self.probe_reads = 0
        self.ingress_rejections = set()
        self.ingress_events = []
        self.email_code = 200
        self.email_retry_after = 60
        self.email_receipt = None
        self.email_lost_response = False
        self.email_state = "RESOLVED"
        self.email_requests = []
        self.email_user_agents = []
        self.sent_mail = []
        self.diagnostic_requests = []
        self.diagnostic_responses = {}
        self.diagnostic_pause = None
        self.clock = time.time()
        self.logs = io.StringIO()
        fixture = self

        class NotionHandler(BaseHTTPRequestHandler):
            def log_message(self, *_args):
                pass

            def reply(self, code, body, retry=0, headers=None):
                data = json.dumps(body).encode()
                self.send_response(code)
                self.send_header("Content-Length", str(len(data)))
                for key, value in {"Content-Type": "application/json; charset=utf-8", **(headers or {})}.items():
                    self.send_header(key, value)
                if retry:
                    self.send_header("Retry-After", str(retry))
                self.end_headers()
                self.wfile.write(data)

            def do_POST(self):
                self.handle_write()

            def do_PATCH(self):
                self.handle_write()

            def do_GET(self):
                fixture.probe_reads += 1
                self.reply(200 if fixture.probe_ok else 503, {})

            def handle_write(self):
                if self.path.startswith("/ingest/"):
                    route = self.path.removeprefix("/ingest/")
                    body = json.loads(self.rfile.read(int(self.headers["Content-Length"])))
                    if (route, body["state"]) in fixture.ingress_rejections:
                        code = 503
                    elif route == "email":
                        code = fixture.send_email(body["state"])
                    else:
                        code = fixture.send(body["state"])
                    fixture.ingress_events.append((route, body["state"], code))
                    return self.reply(code, {})
                if self.path == "/email":
                    fixture.email_user_agents.append(self.headers.get("User-Agent"))
                    body = json.loads(self.rfile.read(int(self.headers["Content-Length"])))
                    if body.get("state") == "INVALID":
                        phase = "authenticated" if self.headers.get("Authorization") else "unauthenticated"
                        fixture.diagnostic_requests.append({"phase": phase, "method": self.command,
                                                            "content_type": self.headers.get("Content-Type"),
                                                            "user_agent": self.headers.get("User-Agent"), "body": body})
                        if fixture.diagnostic_pause and phase == "unauthenticated":
                            started, release = fixture.diagnostic_pause
                            started.set()
                            release.wait(5)
                        default = ((400, {"error": "invalid_transition"}, {})
                                   if self.headers.get("Authorization") == "Bearer email-api-fixture-secret"
                                   else (401, {"error": "unauthorized"}, {}))
                        code, payload, headers = fixture.diagnostic_responses.get(phase, default)
                        return self.reply(code, payload, headers=headers)
                    if self.headers.get("Authorization") != "Bearer email-api-fixture-secret":
                        return self.reply(401, {})
                    fixture.assertEqual(set(body), {"endpoint", "state"})
                    if body["state"] not in ("TRIGGERED", "RESOLVED"):
                        return self.reply(400, {})
                    fixture.email_requests.append(body)
                    if fixture.email_code != 200:
                        return self.reply(fixture.email_code, {"status": "private-response-must-not-be-logged"}, fixture.email_retry_after)
                    duplicate = body["state"] == fixture.email_state
                    if not duplicate:
                        fixture.sent_mail.append(body)
                        fixture.email_state = body["state"]
                    if fixture.email_lost_response:
                        fixture.email_lost_response = False
                        self.connection.shutdown(socket.SHUT_RDWR)
                        return
                    receipt = fixture.email_receipt or {
                        "status": "duplicate" if duplicate else "accepted_by_provider",
                        "incidentId": "incident-fixture", "messageId": "message-fixture",
                    }
                    return self.reply(200, receipt)
                if self.headers.get("Authorization") != "Bearer api-fixture-secret":
                    return self.reply(401, {})
                body = json.loads(self.rfile.read(int(self.headers["Content-Length"])))
                if self.path == "/data_sources/source/query":
                    if fixture.query_mode == "rate-limit":
                        return self.reply(429, {"message": "private-response-must-not-be-logged"}, 60)
                    key = body["filter"]["rich_text"]["equals"]
                    pages = [page for page in fixture.pages.values() if page["properties"]["Incident ID"]["rich_text"][0]["text"]["content"] == key]
                    return self.reply(200, {"results": pages, "has_more": False})
                if self.path == "/pages":
                    fixture.creates += 1
                    if fixture.create_mode == "rate-limit":
                        return self.reply(429, {}, 60)
                    if fixture.create_mode == "uncommitted-503":
                        return self.reply(503, {})
                    page_id = f"page-{len(fixture.pages) + 1}"
                    fixture.pages[page_id] = {"id": page_id, "properties": body["properties"]}
                    fixture.assertEqual(body["notifications"], {"mode": "silent"})
                    if fixture.create_mode == "committed-503":
                        return self.reply(503, {"additional_data": {"committed_resource_id": page_id}})
                    if fixture.create_mode == "ambiguous-503":
                        return self.reply(503, {})
                    return self.reply(200, fixture.pages[page_id])
                if self.command == "PATCH" and self.path.startswith("/pages/"):
                    if fixture.patch_mode == "unavailable":
                        return self.reply(503, {})
                    page_id = self.path.removeprefix("/pages/")
                    fixture.pages[page_id]["properties"] = body["properties"]
                    return self.reply(200, fixture.pages[page_id])
                self.reply(404, {})

        self.api = ThreadingHTTPServer(("127.0.0.1", 0), NotionHandler)
        self.start_server(self.api)
        api_patch = patch.object(incidents, "NOTION_API", f"http://127.0.0.1:{self.api.server_port}")
        api_patch.start()
        self.addCleanup(api_patch.stop)
        self.notion = incidents.Notion("api-fixture-secret", "source", "https://gatus.example.test/")
        self.receiver, _wake = incidents.make_server(self.store, "ingest-fixture-secret", [ENDPOINT], 0)
        self.start_server(self.receiver)
        self.url = f"http://127.0.0.1:{self.receiver.server_port}"
        self.email_db = Path(self.tmp.name) / "email.sqlite"
        self.email_queue = incidents.EmailQueue(self.email_db)
        email_receiver, _wake = incidents.make_server(self.email_queue, EMAIL_INGEST, [ENDPOINT], 0)
        self.start_server(email_receiver)
        self.email_url = f"http://127.0.0.1:{email_receiver.server_port}"
        self.email = incidents.CloudflareEmail("email-api-fixture-secret", f"http://127.0.0.1:{self.api.server_port}/email")

    def start_server(self, server):
        thread = threading.Thread(target=server.serve_forever, daemon=True)
        thread.start()
        self.addCleanup(thread.join)
        self.addCleanup(server.server_close)
        self.addCleanup(server.shutdown)

    def send(self, state, *, endpoint=ENDPOINT, token="ingest-fixture-secret", extra=None, url=None):
        payload = {"endpoint": endpoint, "state": state, **(extra or {})}
        request = Request((url or self.url) + "/events", data=json.dumps(payload).encode(), headers={
            "Authorization": "Bearer " + token, "Content-Type": "application/json",
        })
        try:
            with urlopen(request, timeout=3) as response:
                return response.status
        except HTTPError as error:
            with error:
                return error.code

    def health(self, url=None):
        try:
            response = urlopen((url or self.url) + "/health", timeout=3)
        except HTTPError as error:
            response = error
        with response:
            return response.status, json.load(response)

    def deliver(self, advance=0):
        self.clock += advance
        with patch.object(incidents.time, "time", return_value=self.clock), redirect_stdout(self.logs):
            return self.store.deliver_one(self.notion)

    def deliver_email(self, advance=0):
        self.clock += advance
        with patch.object(incidents.time, "time", return_value=self.clock), redirect_stdout(self.logs):
            return self.email_queue.deliver_one(self.email)

    def send_email(self, state):
        return self.send(state, token=EMAIL_INGEST, url=self.email_url)

    def prepared_config(self, name):
        fixtures = json.loads(Path(os.environ["GATUS_CONFIG_FIXTURES"]).read_text())
        prepare = Path(fixtures[name]["prepare"].removeprefix("+")).read_text()
        runtime = Path(self.tmp.name) / name
        runtime.mkdir(exist_ok=True)
        script = runtime / "prepare.sh"
        script.write_text(prepare.replace("/run/gatus", str(runtime)))
        result = subprocess.run(["bash", str(script)], capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        return json.loads((runtime / "config.yaml").read_text()), fixtures

    @unittest.skipUnless(os.environ.get("GATUS_CONFIG_FIXTURES"), "Nix configuration fixture required")
    def test_disabled_defaults_scope_and_runtime_secret_preparation(self):
        config, fixtures = self.prepared_config("enabled")
        disabled, _ = self.prepared_config("disabled")
        self.assertNotIn("alerting", disabled)
        self.assertFalse(fixtures["disabled"]["hasNotionService"])
        self.assertFalse(fixtures["disabled"]["hasEmailService"])
        self.assertTrue(all(fixtures["enabled"]["assertions"]))
        self.assertTrue(all(fixtures["disabled"]["assertions"]))
        self.assertFalse(any(fixtures["invalidAssertions"]))
        for endpoint in config["endpoints"]:
            types = [alert["type"] for alert in endpoint.get("alerts", [])]
            if endpoint["name"] == "Home Assistant Runtime":
                self.assertEqual(types, ["custom", "custom"])
                self.assertEqual([alert["description"] for alert in endpoint["alerts"]], ["gatus-email", "gatus-notion"])
                self.assertTrue(all(alert["durable-delivery"] for alert in endpoint["alerts"]))
                headers = [alert["provider-override"]["headers"]["Authorization"] for alert in endpoint["alerts"]]
                self.assertEqual(headers, ["Bearer " + EMAIL_INGEST, "Bearer ingest-fixture-secret"])
            else:
                self.assertEqual(types, [])
        self.assertNotIn("email", config["alerting"])
        prepare = Path(fixtures["enabled"]["prepare"].removeprefix("+")).read_text()
        template = json.loads(Path(re.search(r"install -m 600 (\S+) /run/gatus/config.yaml", prepare)[1]).read_text())
        runtime = next(ep for ep in template["endpoints"] if ep["name"] == "Home Assistant Runtime")
        self.assertEqual(runtime["alerts"][0]["provider-override"]["headers"]["Authorization"], "Bearer __email_INGEST_TOKEN__")
        for name, token in (("emailOnly", EMAIL_INGEST), ("notionOnly", "ingest-fixture-secret")):
            single, _ = self.prepared_config(name)
            runtime = next(ep for ep in single["endpoints"] if ep["name"] == "Home Assistant Runtime")
            self.assertEqual(len(runtime["alerts"]), 1)
            self.assertEqual(runtime["alerts"][0]["provider-override"]["headers"]["Authorization"], "Bearer " + token)

    @unittest.skipUnless(os.environ.get("GATUS_BINARY"), "native Gatus binary required")
    def test_native_gatus_queues_ordered_email_and_one_notion_incident(self):
        config, fixtures = self.prepared_config("enabled")
        with socket.socket() as port:
            port.bind(("127.0.0.1", 0))
            email_port = port.getsockname()[1]
        args = shlex.split(fixtures["enabled"]["email"]["ExecStart"])
        replacements = {
            "--state-file": str(Path(self.tmp.name) / "email-service.sqlite"),
            "--email-url": self.email.url,
            "--port": str(email_port),
        }
        for credential in fixtures["enabled"]["email"]["LoadCredential"]:
            name, path = credential.split(":", 1)
            replacements["--token-file" if name == "email-token" else "--ingest-token-file"] = path
        for flag, value in replacements.items():
            args[args.index(flag) + 1] = value
        email_url = f"http://127.0.0.1:{email_port}"
        config["storage"]["path"] = str(Path(self.tmp.name) / "gatus.sqlite")
        config["endpoints"] = [ep for ep in config["endpoints"] if ep["name"] == "Home Assistant Runtime"]
        for alert, url in zip(config["endpoints"][0]["alerts"], (email_url, self.url)):
            alert["provider-override"]["url"] = url + "/events"
        config["endpoints"][0]["url"] = f"http://127.0.0.1:{self.api.server_port}/probe"
        config["endpoints"][0]["interval"] = "1s"
        with socket.socket() as port:
            port.bind(("127.0.0.1", 0))
            config["web"]["port"] = port.getsockname()[1]
        path = Path(self.tmp.name) / "native-gatus.json"
        path.write_text(json.dumps(config))
        with (Path(self.tmp.name) / "gatus.log").open("w+") as log:
            email_process = subprocess.Popen(args, stdout=log, stderr=log)
            self.addCleanup(lambda: email_process.wait(timeout=5))
            self.addCleanup(email_process.terminate)
            process = subprocess.Popen([os.environ["GATUS_BINARY"]], env={**os.environ, "GATUS_CONFIG_PATH": str(path)}, stdout=log, stderr=log)
            try:
                for recovered in (False, True):
                    self.probe_ok = recovered
                    deadline = time.monotonic() + 15
                    while time.monotonic() < deadline:
                        self.deliver()
                        if len(self.sent_mail) >= (2 if recovered else 1) and self.pages:
                            state = self.pages["page-1"]["properties"]["Status"]["select"]["name"]
                            if state == ("Resolved" if recovered else "Open"):
                                break
                        self.assertIsNone(process.poll(), "Gatus exited before sending alerts")
                        self.assertIsNone(email_process.poll(), "Email service exited before delivering transitions")
                        time.sleep(0.05)
                    else:
                        log.seek(0)
                        self.fail("Native Gatus did not deliver transitions:\n" + log.read())
                self.assertEqual(len(self.pages), 1)
                self.assertEqual(self.sent_mail, [
                    {"endpoint": ENDPOINT, "state": "TRIGGERED"},
                    {"endpoint": ENDPOINT, "state": "RESOLVED"},
                ])
                self.assertEqual(self.health()[1]["pending"], 0)
                self.assertEqual(self.health(email_url)[1]["pending"], 0)
            finally:
                process.terminate()
                process.wait(timeout=5)

    def start_native_gatus(self):
        if not hasattr(self, "native_config"):
            config, _ = self.prepared_config("enabled")
            config["storage"]["path"] = str(Path(self.tmp.name) / "gatus.sqlite")
            config["endpoints"] = [ep for ep in config["endpoints"] if ep["name"] == "Home Assistant Runtime"]
            endpoint = config["endpoints"][0]
            endpoint["url"] = f"http://127.0.0.1:{self.api.server_port}/probe"
            endpoint["interval"] = "1s"
            for alert, route in zip(endpoint["alerts"], ("email", "notion")):
                alert["provider-override"]["url"] = f"http://127.0.0.1:{self.api.server_port}/ingest/{route}"
            with socket.socket() as port:
                port.bind(("127.0.0.1", 0))
                config["web"]["port"] = port.getsockname()[1]
            self.native_config = Path(self.tmp.name) / "native.json"
            self.native_config.write_text(json.dumps(config))
            self.native_log = (Path(self.tmp.name) / "native.log").open("w+")
            self.addCleanup(self.native_log.close)
        process = subprocess.Popen([os.environ["GATUS_BINARY"]], env={
            **os.environ, "GATUS_CONFIG_PATH": str(self.native_config),
        }, stdout=self.native_log, stderr=self.native_log)
        self.native_process = process

        def stop():
            if process.poll() is None:
                process.terminate()
                process.wait(timeout=5)
        self.addCleanup(stop)

    def wait_native(self, predicate):
        deadline = time.monotonic() + 15
        while time.monotonic() < deadline:
            if predicate():
                return
            if self.native_process.poll() is not None:
                break
            time.sleep(0.05)
        self.native_log.seek(0)
        self.fail(f"Native delivery condition failed: {self.ingress_events}\n{self.native_log.read()}")

    def accepted(self, route):
        return [state for target, state, code in self.ingress_events if target == route and code == 202]

    @unittest.skipUnless(os.environ.get("GATUS_BINARY"), "native Gatus binary required")
    def test_native_restart_keeps_routes_independent_after_partial_acceptance(self):
        self.ingress_rejections.add(("email", "TRIGGERED"))
        self.start_native_gatus()
        self.wait_native(lambda: ("email", "TRIGGERED", 503) in self.ingress_events and self.accepted("notion") == ["TRIGGERED"])
        baseline = self.probe_reads
        self.wait_native(lambda: self.probe_reads >= baseline + 2)
        self.native_process.terminate()
        self.native_process.wait(timeout=5)
        self.ingress_rejections.clear()
        self.start_native_gatus()
        self.wait_native(lambda: self.accepted("email") == ["TRIGGERED"])
        self.probe_ok = True
        self.wait_native(lambda: all(self.accepted(route) == ["TRIGGERED", "RESOLVED"] for route in ("email", "notion")))
        self.deliver()
        self.deliver_email()
        self.deliver_email()
        self.assertEqual(len(self.pages), 1)
        self.assertEqual(self.pages["page-1"]["properties"]["Status"]["select"]["name"], "Resolved")
        self.assertEqual([event["state"] for event in self.sent_mail], ["TRIGGERED", "RESOLVED"])

    @unittest.skipUnless(os.environ.get("GATUS_BINARY"), "native Gatus binary required")
    def test_native_rejected_recovery_preserves_later_incident_across_restart(self):
        self.start_native_gatus()
        self.wait_native(lambda: all(self.accepted(route) == ["TRIGGERED"] for route in ("email", "notion")))
        self.ingress_rejections.update((route, "RESOLVED") for route in ("email", "notion"))
        self.probe_ok = True
        self.wait_native(lambda: all((route, "RESOLVED", 503) in self.ingress_events for route in ("email", "notion")))
        self.probe_ok = False
        baseline = self.probe_reads
        self.wait_native(lambda: self.probe_reads >= baseline + 4)
        self.native_process.terminate()
        self.native_process.wait(timeout=5)
        self.start_native_gatus()
        self.probe_ok = True
        baseline = self.probe_reads
        self.wait_native(lambda: self.probe_reads >= baseline + 3)
        self.ingress_rejections.clear()
        expected = ["TRIGGERED", "RESOLVED", "TRIGGERED", "RESOLVED"]
        self.wait_native(lambda: all(self.accepted(route) == expected for route in ("email", "notion")))
        for _ in range(4):
            self.deliver()
            self.deliver_email()
        self.assertEqual(len(self.pages), 2)
        self.assertTrue(all(page["properties"]["Status"]["select"]["name"] == "Resolved" for page in self.pages.values()))
        self.assertEqual([event["state"] for event in self.sent_mail], expected)
        self.assertEqual(self.health()[1]["pending"], 0)
        self.assertEqual(self.health(self.email_url)[1]["pending"], 0)

    def test_failure_restart_duplicate_and_recovery_share_one_page(self):
        self.assertEqual(self.send("TRIGGERED"), 202)
        self.store = incidents.Incidents(self.db)
        self.deliver()
        self.assertEqual(self.send("TRIGGERED"), 202)
        self.deliver()
        self.assertEqual(len(self.pages), 1)
        opened = self.pages["page-1"]["properties"]
        self.assertEqual(opened["Status"]["select"]["name"], "Open")
        self.assertEqual(opened["Recovered"], {"date": None})
        self.assertEqual(self.send("RESOLVED"), 202)
        self.deliver()
        self.assertEqual(self.send("RESOLVED"), 202)
        self.assertFalse(self.deliver())
        resolved = self.pages["page-1"]["properties"]
        self.assertEqual(resolved["Status"]["select"]["name"], "Resolved")
        self.assertEqual(resolved["Detected"], opened["Detected"])
        self.assertIsNotNone(resolved["Recovered"]["date"])
        self.assertEqual(self.health()[1]["pending"], 0)
        self.assertEqual(self.send("TRIGGERED"), 202)
        self.deliver()
        self.assertEqual(len(self.pages), 2)

    def test_outage_and_recovery_survive_notion_unavailability(self):
        self.query_mode = "rate-limit"
        self.assertEqual(self.send("TRIGGERED"), 202)
        self.deliver()
        self.assertEqual(self.health()[0], 503)
        self.query_mode = "success"
        self.assertFalse(self.deliver(59))
        self.store = incidents.Incidents(self.db)
        self.assertEqual(self.send("RESOLVED"), 202)
        self.assertFalse(self.deliver())
        # A second incident must not bypass the connection-wide Retry-After.
        self.assertEqual(self.send("TRIGGERED"), 202)
        self.assertFalse(self.deliver())
        self.deliver(1)
        self.deliver()
        self.assertEqual(len(self.pages), 2)
        self.assertEqual(self.pages["page-1"]["properties"]["Status"]["select"]["name"], "Resolved")
        self.assertEqual(self.health()[0], 200)
        self.assertNotIn("private-response", self.logs.getvalue())
        self.assertNotIn("fixture-secret", self.logs.getvalue())

    def test_create_rate_limit_is_retryable_but_unknown_commit_is_not_repeated(self):
        self.create_mode = "rate-limit"
        self.send("TRIGGERED")
        self.deliver()
        self.create_mode = "success"
        self.assertFalse(self.deliver(59))
        self.deliver(1)
        self.assertEqual(len(self.pages), 1)
        self.send("RESOLVED")
        self.deliver()
        self.send("TRIGGERED")
        self.create_mode = "uncommitted-503"
        self.deliver()
        attempts = self.creates
        self.store = incidents.Incidents(self.db)
        self.query_mode = "rate-limit"
        self.deliver(300)
        self.query_mode = "success"
        self.deliver(300)
        self.assertEqual(self.creates, attempts)
        self.assertEqual(self.health()[0], 503)

    def test_committed_or_ambiguous_503_reconciles_without_duplicate_creation(self):
        for mode in ("committed-503", "ambiguous-503"):
            with self.subTest(mode=mode):
                self.create_mode = mode
                before = self.creates
                self.send("TRIGGERED")
                self.deliver()
                self.store = incidents.Incidents(self.db)
                self.send("RESOLVED")
                self.deliver(300)
                self.assertEqual(self.creates, before + 1)
                self.assertEqual(self.pages[f"page-{len(self.pages)}"]["properties"]["Status"]["select"]["name"], "Resolved")
                self.assertEqual(self.health()[1]["pending"], 0)

    def test_recovery_update_retries_and_recovery_without_failure_is_ignored(self):
        self.send("RESOLVED")
        self.assertFalse(self.deliver())
        self.send("TRIGGERED")
        self.deliver()
        self.patch_mode = "unavailable"
        self.send("RESOLVED")
        self.deliver()
        self.assertEqual(self.health()[0], 503)
        self.patch_mode = "success"
        self.deliver(5)
        self.assertEqual(self.pages["page-1"]["properties"]["Status"]["select"]["name"], "Resolved")
        self.assertEqual(len(self.pages), 1)

    def test_ingestion_auth_privacy_backpressure_and_retention(self):
        self.assertEqual(self.send("TRIGGERED", token="wrong"), 401)
        self.assertEqual(self.send("TRIGGERED", endpoint="unapproved"), 400)
        self.assertEqual(self.send("TRIGGERED", extra={"raw_ha_data": "private"}), 400)
        self.assertEqual(self.send([]), 400)
        self.assertEqual(self.health()[1]["pending"], 0)
        with patch.object(incidents, "QUEUE_LIMIT", 1):
            self.send("TRIGGERED")
            self.send("RESOLVED")
            self.assertEqual(self.send("TRIGGERED"), 503)
            self.assertEqual(self.health()[0], 503)
        self.deliver()
        with patch.object(incidents, "HISTORY_LIMIT", 2):
            for _ in range(4):
                self.send("TRIGGERED")
                self.send("RESOLVED")
                self.deliver()
            with closing(sqlite3.connect(self.db)) as db:
                self.assertEqual(db.execute("SELECT count(*) FROM incidents").fetchone()[0], 2)
        self.assertEqual(len(self.pages), 5)
        self.assertNotIn(ENDPOINT, json.dumps(self.health()))

    def test_pending_age_not_historical_outage_age_controls_health(self):
        self.send("TRIGGERED")
        with patch.object(incidents.time, "time", return_value=self.clock + 301):
            self.assertEqual(self.health()[0], 503)
        self.deliver()
        self.send("RESOLVED")
        self.assertEqual(self.health()[0], 200)

    def acceptance(self, token="email-api-fixture-secret", *, producer=None):
        token_file = Path(self.tmp.name) / "acceptance-token"
        ingest_file = Path(self.tmp.name) / "acceptance-ingest"
        token_file.write_text(token)
        ingest_file.write_text(EMAIL_INGEST)
        token_file.chmod(0o600)
        ingest_file.chmod(0o600)
        with (patch.object(incidents, "require_email_test_preconditions",
                           side_effect=(lambda: incidents.require_fresh_producer(producer)) if producer else None),
              patch.dict(os.environ, {"GATUS_EMAIL_TEST_FAMILY_REVISION": "a" * 40}),
              redirect_stdout(self.logs)):
            incidents.email_acceptance_test(
                Path(self.tmp.name) / "acceptance", f"http://127.0.0.1:{self.api.server_port}/email",
                token_file, ingest_file,
            )

    def test_acceptance_pair_is_synthetic_isolated_and_never_replayed(self):
        producer = Path(self.tmp.name) / "producer.sqlite"
        with closing(sqlite3.connect(producer)) as db:
            db.execute("CREATE TABLE history (value TEXT)")
            db.commit()
        self.acceptance(producer=producer)
        self.assertEqual([body["state"] for body in self.sent_mail], ["TRIGGERED", "RESOLVED"])
        self.assertEqual(self.email_queue.health()["pending"], 0)
        with self.email_queue.connect() as db:
            self.assertEqual(db.execute("SELECT count(*) FROM events").fetchone()[0], 0)
        journal = Path(self.tmp.name) / "acceptance/claim.jsonl"
        records = [json.loads(line) for line in journal.read_text().splitlines()]
        self.assertTrue(all(record["synthetic"] for record in records))
        self.assertEqual([record["state"] for record in records[1:]], ["TRIGGERED", "RESOLVED"])
        self.assertIn('"inbox_delivery": "unverified"', self.logs.getvalue())
        self.assertEqual(self.email_user_agents,
                         ["dotfiles-gatus-email/1.0 (+https://github.com/edmundmiller/dotfiles)"] * 4)
        with self.assertRaises(incidents.DeliveryError):
            self.acceptance()
        self.assertEqual(len(self.email_requests), 2)
        self.assertNotIn("email-api-fixture-secret", journal.read_text() + self.logs.getvalue())

    def test_acceptance_retained_producer_wal_blocks_without_touching_source(self):
        producer = Path(self.tmp.name) / "producer.sqlite"
        with closing(sqlite3.connect(producer)) as db:
            db.execute("PRAGMA journal_mode=WAL")
            db.execute("CREATE TABLE alert_delivery_state (state TEXT)")
            db.execute("INSERT INTO alert_delivery_state VALUES (?)", ('{"Triggered":true,"Pending":[false]}',))
            db.commit()
            before = {path.name: path.read_bytes() for path in producer.parent.glob("producer.sqlite*")}
            with self.assertRaisesRegex(incidents.DeliveryError, "retained-producer-state"):
                self.acceptance(producer=producer)
            self.assertEqual(before, {path.name: path.read_bytes() for path in producer.parent.glob("producer.sqlite*")})
        self.assertEqual(self.email_requests, [])
        self.assertFalse((Path(self.tmp.name) / "acceptance/claim.jsonl").exists())

    def test_acceptance_duplicate_trigger_never_resolves_existing_incident(self):
        self.email_state = "TRIGGERED"
        with self.assertRaises(incidents.DeliveryError):
            self.acceptance()
        self.assertEqual([body["state"] for body in self.email_requests], ["TRIGGERED"])
        self.assertEqual(self.sent_mail, [])
        self.assertEqual(self.email_state, "TRIGGERED")

    def test_acceptance_unknown_delivery_preserves_head_without_recovery_or_replay(self):
        self.email_code = 409
        with self.assertRaises(incidents.DeliveryError):
            self.acceptance()
        self.assertEqual([body["state"] for body in self.email_requests], ["TRIGGERED"])
        queue = incidents.EmailQueue(Path(self.tmp.name) / "acceptance/events.sqlite")
        self.assertEqual(queue.health()["pending"], 1)
        with self.assertRaises(incidents.DeliveryError):
            self.acceptance()
        self.assertEqual(len(self.email_requests), 1)

    def test_acceptance_refuses_even_a_stopped_configured_production_receiver(self):
        with (patch.object(incidents.socket, "gethostname", return_value="nuc"),
              patch.object(incidents.os, "geteuid", return_value=0),
              patch.object(incidents.subprocess, "run", return_value=subprocess.CompletedProcess([], 0, "loaded\n"))):
            with self.assertRaisesRegex(incidents.DeliveryError, "production-email-absent"):
                incidents.email_acceptance_test()
        self.assertEqual(self.email_requests, [])

    def test_acceptance_auth_mismatch_claim_cannot_be_retried(self):
        with self.assertRaises(incidents.DeliveryError):
            self.acceptance("wrong-token")
        with self.assertRaises(FileExistsError):
            self.acceptance()
        self.assertEqual(self.email_requests, [])
        self.assertEqual(self.sent_mail, [])

    def diagnostic(self, name="diagnostic", *, prior_diagnostic=None):
        prior = Path(self.tmp.name) / "acceptance"
        prior.mkdir(exist_ok=True)
        if not (prior / "claim.jsonl").exists():
            (prior / "claim.jsonl").write_text(json.dumps({
                "synthetic": True, "family_revision": "b" * 40, "started": "2026-11-18T09:38:51Z",
            }) + "\n")
        token = Path(self.tmp.name) / "diagnostic-token"
        token.write_text("email-api-fixture-secret")
        token.chmod(0o600)
        with (patch.object(incidents, "require_email_test_preconditions"),
              patch.dict(os.environ, {"GATUS_EMAIL_TEST_FAMILY_REVISION": "a" * 40,
                                     "GATUS_EMAIL_DIAGNOSTIC_FAMILY_VERSION": "12345678-abcd-1234-abcd-123456789abc",
                                     "GATUS_EMAIL_DIAGNOSTIC_RUN_ID": "44277758687"}),
              redirect_stdout(self.logs)):
            incidents.email_preflight_diagnostic(
                Path(self.tmp.name) / name, prior, f"http://127.0.0.1:{self.api.server_port}/email", token,
                prior_diagnostic_directory=prior_diagnostic,
            )

    def test_diagnostic_only_probes_preserve_failed_intent_and_refuse_replay(self):
        prior = Path(self.tmp.name) / "acceptance/claim.jsonl"
        prior.parent.mkdir()
        before = (json.dumps({"synthetic": True, "family_revision": "b" * 40,
                              "started": "2026-11-18T09:38:51Z"}) + "\n").encode()
        prior.write_bytes(before)
        self.diagnostic_responses["authenticated"] = (400, {"error": "invalid_transition"}, {"CF-Ray": "0123456789abcdef-DFW"})
        self.diagnostic()
        events = [json.loads(line) for line in (Path(self.tmp.name) / "diagnostic/claim.jsonl").read_text().splitlines()]
        results = [event for event in events if "status" in event and "event" not in event]
        self.assertEqual([(event["phase"], event["status"], event["error"]) for event in results],
                         [("unauthenticated", 401, "unauthorized"), ("authenticated", 400, "invalid_transition")])
        self.assertEqual(results[-1]["cf_ray"], "0123456789abcdef-DFW")
        self.assertEqual(len({event["correlation_id"] for event in results}), 2)
        self.assertEqual([request["body"] for request in self.diagnostic_requests],
                         [{"endpoint": ENDPOINT, "state": "INVALID"}] * 2)
        self.assertTrue(all(request["method"] == "POST" and request["content_type"] == "application/json"
                            for request in self.diagnostic_requests))
        self.assertEqual([request["user_agent"] for request in self.diagnostic_requests],
                         ["dotfiles-gatus-email/1.0 (+https://github.com/edmundmiller/dotfiles)"] * 2)
        self.assertTrue(events[-1]["expected_rejections_confirmed"])
        self.assertEqual(events[-1]["valid_transitions_sent"], 0)
        with self.assertRaises(FileExistsError):
            self.diagnostic()
        self.assertEqual(len(self.diagnostic_requests), 2)
        self.assertEqual(prior.read_bytes(), before)
        self.assertEqual(len(before.splitlines()), 1)
        self.assertFalse((prior.parent / "events.sqlite").exists())
        self.assertEqual(self.email_requests, [])
        self.assertEqual(self.sent_mail, [])
        self.assertNotIn("email-api-fixture-secret", self.logs.getvalue())

    def test_diagnostic_retains_status_phase_and_hides_unknown_response_details(self):
        cases = (("unauthenticated", 403, {"error": "private-response"}, {"Content-Type": "text/html"}),
                 ("authenticated", 401, {"error": "unauthorized"}, {}),
                 ("authenticated", 415, {"error": "unsupported_media_type"}, {}),
                 ("authenticated", 400, {"error": "invalid_transition", "private": "private-response"}, {}),
                 ("authenticated", 200, {"status": "accepted_by_provider", "private": "private-response"}, {}))
        for index, (phase, status, body, headers) in enumerate(cases):
            with self.subTest(phase=phase, status=status):
                self.diagnostic_responses = {phase: (status, body, {"CF-Ray": "private-ray", **headers})}
                before = len(self.diagnostic_requests)
                with self.assertRaises(incidents.DeliveryError):
                    self.diagnostic(f"diagnostic-{index}")
                records = [json.loads(line) for line in (Path(self.tmp.name) / f"diagnostic-{index}/claim.jsonl").read_text().splitlines()]
                self.assertEqual(records[-1]["phase"], phase)
                self.assertEqual(records[-1]["status"], status)
                self.assertEqual(len(self.diagnostic_requests) - before, 1 if phase == "unauthenticated" else 2)
                self.assertNotIn("private-response", json.dumps(records))
                self.assertNotIn("private-ray", json.dumps(records))
        self.assertEqual(self.email_requests, [])
        self.assertEqual(self.sent_mail, [])
        self.assertNotIn("email-api-fixture-secret", self.logs.getvalue())

    def test_diagnostic_does_not_follow_authenticated_redirects(self):
        for code, location in ((302, "/private-location?token=private-query"),
                               (307, self.email_url + "/events?token=private-query")):
            with self.subTest(code=code):
                self.diagnostic_responses = {"authenticated": (code, {}, {"Location": location})}
                with self.assertRaises(incidents.DeliveryError):
                    self.diagnostic(f"diagnostic-{code}")
                records = [json.loads(line) for line in (Path(self.tmp.name) / f"diagnostic-{code}/claim.jsonl").read_text().splitlines()]
                self.assertEqual(records[-1]["status"], code)
                self.assertEqual(records[-1]["redirect"]["path"], "other")
                if code == 307:
                    self.assertEqual(records[-1]["redirect"]["port"], "other")
                self.assertNotIn("private-location", json.dumps(records))
                self.assertNotIn("private-query", json.dumps(records))
        self.assertEqual(self.probe_reads, 0)
        self.assertEqual(self.email_queue.health()["pending"], 0)
        self.assertEqual(self.email_requests, [])
        self.assertEqual(self.sent_mail, [])

    def test_diagnostic_refuses_prior_acknowledgement_or_fifo_sidecar(self):
        prior = Path(self.tmp.name) / "acceptance"
        prior.mkdir()
        original = json.dumps({"synthetic": True, "family_revision": "b" * 40, "started": "earlier"}) + "\n"
        journal = prior / "claim.jsonl"
        journal.write_text(original + json.dumps({"state": "TRIGGERED"}) + "\n")
        with self.assertRaisesRegex(incidents.DeliveryError, "prior-intent-needs-reconciliation"):
            self.diagnostic()
        journal.write_text(original)
        (prior / "events.sqlite-wal").write_bytes(b"retained producer work")
        with self.assertRaisesRegex(incidents.DeliveryError, "prior-intent-needs-reconciliation"):
            self.diagnostic()
        self.assertEqual(self.diagnostic_requests, [])
        self.assertFalse((Path(self.tmp.name) / "diagnostic/claim.jsonl").exists())

    def test_client_diagnostic_preserves_both_claims_and_refuses_unreconciled_state(self):
        self.diagnostic_responses = {"unauthenticated": (
            403, {}, {"Content-Type": "text/plain", "CF-Ray": "0123456789abcdef-DFW"},
        )}
        with self.assertRaises(incidents.DeliveryError):
            self.diagnostic()
        prior = Path(self.tmp.name) / "diagnostic"
        acceptance = Path(self.tmp.name) / "acceptance/claim.jsonl"
        before = (prior / "claim.jsonl").read_bytes()
        acceptance_before = acceptance.read_bytes()
        self.diagnostic_responses = {}
        self.diagnostic("client-diagnostic", prior_diagnostic=prior)
        self.assertEqual((prior / "claim.jsonl").read_bytes(), before)
        self.assertEqual(acceptance.read_bytes(), acceptance_before)
        claim = Path(self.tmp.name) / "client-diagnostic/claim.jsonl"
        records = [json.loads(line) for line in claim.read_text().splitlines()]
        self.assertEqual(records[0]["prior_diagnostic_sha256"], hashlib.sha256(before).hexdigest())
        self.assertTrue(records[-1]["expected_rejections_confirmed"])
        with self.assertRaises(FileExistsError):
            self.diagnostic("client-diagnostic", prior_diagnostic=prior)
        self.assertEqual(len(self.diagnostic_requests), 3)

        original = [json.loads(line) for line in before.splitlines()]
        mutations = [original + [{"phase": "authenticated"}],
                     [original[0], {**original[1], "phase": "authenticated"}, *original[2:]],
                     [original[0], original[1], original[2], {**original[3], "status": 401}],
                     [{**original[0], "prior_intent_sha256": "0" * 64}, *original[1:]]]
        for index, events in enumerate(mutations):
            with self.subTest(index=index):
                (prior / "claim.jsonl").write_text("".join(json.dumps(event) + "\n" for event in events))
                with self.assertRaisesRegex(incidents.DeliveryError, "prior-probe-needs-reconciliation"):
                    self.diagnostic(f"blocked-{index}", prior_diagnostic=prior)
                self.assertFalse((Path(self.tmp.name) / f"blocked-{index}/claim.jsonl").exists())
        (prior / "claim.jsonl").write_bytes(before)
        for suffix in ("", "-wal", "-shm", "-journal"):
            with self.subTest(suffix=suffix):
                sidecar = prior / ("events.sqlite" + suffix)
                sidecar.write_bytes(b"retained queue")
                with self.assertRaisesRegex(incidents.DeliveryError, "prior-probe-needs-reconciliation"):
                    self.diagnostic("blocked-queue", prior_diagnostic=prior)
                self.assertEqual(sidecar.read_bytes(), b"retained queue")
                sidecar.unlink()
        self.assertEqual(len(self.diagnostic_requests), 3)
        self.assertEqual(self.email_requests, [])
        self.assertEqual(self.sent_mail, [])

    def test_diagnostic_network_error_is_classified_without_private_exception_text(self):
        with patch("urllib.request.OpenerDirector.open", side_effect=URLError(socket.gaierror("private-network-detail"))):
            with self.assertRaisesRegex(incidents.DeliveryError, "network-failure-no-replay"):
                self.diagnostic()
        records = [json.loads(line) for line in (Path(self.tmp.name) / "diagnostic/claim.jsonl").read_text().splitlines()]
        self.assertEqual(records[-1]["network_error"], "dns")
        self.assertEqual(records[-1]["phase"], "unauthenticated")
        self.assertNotIn("private-network-detail", self.logs.getvalue())
        self.assertEqual(self.diagnostic_requests, [])

    def test_concurrent_diagnostic_cannot_acquire_existing_live_claim(self):
        started, release = threading.Event(), threading.Event()
        self.diagnostic_pause = (started, release)
        errors = []

        def run():
            try:
                self.diagnostic()
            except Exception as error:
                errors.append(type(error).__name__)

        worker = threading.Thread(target=run)
        worker.start()
        try:
            self.assertTrue(started.wait(5))
            with self.assertRaises(FileExistsError):
                self.diagnostic()
        finally:
            release.set()
            worker.join(5)
        self.assertFalse(worker.is_alive())
        self.assertEqual(errors, [])
        self.assertEqual(len(self.diagnostic_requests), 2)
        self.assertEqual(self.sent_mail, [])

    def test_email_retry_keeps_recovery_and_later_incidents_ordered_across_restart(self):
        self.query_mode = "rate-limit"
        self.send("TRIGGERED")
        self.deliver()
        self.assertEqual(self.health()[0], 503)
        self.assertEqual(self.send_email("RESOLVED"), 202)
        self.assertEqual(self.send_email("TRIGGERED"), 202)
        self.assertEqual(self.send_email("TRIGGERED"), 202)
        self.email_code = 503
        self.deliver_email()
        for state in ("RESOLVED", "RESOLVED", "TRIGGERED", "RESOLVED"):
            self.assertEqual(self.send_email(state), 202)
        self.assertEqual(self.health(self.email_url)[1]["pending"], 4)
        self.email_queue = incidents.EmailQueue(self.email_db)
        self.email_code = 200
        self.assertFalse(self.deliver_email(59))
        self.assertEqual(len(self.email_requests), 1)
        self.deliver_email(1)
        for _ in range(3):
            self.deliver_email()
        self.assertEqual([event["state"] for event in self.sent_mail], ["TRIGGERED", "RESOLVED", "TRIGGERED", "RESOLVED"])
        self.assertEqual(self.health(self.email_url)[0], 200)
        self.assertEqual(self.health(self.email_url)[1]["pending"], 0)
        self.assertEqual(self.health()[0], 503)  # Notion is independent.

    def test_email_lost_acceptance_replays_only_the_head_before_recovery(self):
        self.send_email("TRIGGERED")
        self.send_email("RESOLVED")
        self.email_lost_response = True
        self.deliver_email()
        self.assertEqual(self.health(self.email_url)[0], 503)
        self.email_queue = incidents.EmailQueue(self.email_db)
        self.assertFalse(self.deliver_email(4))
        self.deliver_email(1)
        self.deliver_email()
        self.assertEqual([event["state"] for event in self.email_requests], ["TRIGGERED", "TRIGGERED", "RESOLVED"])
        self.assertEqual([event["state"] for event in self.sent_mail], ["TRIGGERED", "RESOLVED"])
        self.assertEqual(self.health(self.email_url)[1]["pending"], 0)

    def test_email_unknown_delivery_blocks_replay_and_recovery_after_restart(self):
        self.send_email("TRIGGERED")
        self.send_email("RESOLVED")
        self.email_code = 409
        self.deliver_email()
        self.email_queue = incidents.EmailQueue(self.email_db)
        self.email_code = 200
        self.assertFalse(self.deliver_email(86400))
        self.assertEqual(len(self.email_requests), 1)
        self.assertEqual(self.sent_mail, [])
        self.assertEqual(self.health(self.email_url)[0], 503)
        self.assertEqual(self.health(self.email_url)[1]["pending"], 2)
        self.assertNotIn("private-response", self.logs.getvalue())
        self.assertNotIn("fixture-secret", self.logs.getvalue())

    def test_email_rate_limit_honors_long_retry_after_across_restart(self):
        self.send_email("TRIGGERED")
        self.send_email("RESOLVED")
        self.email_code = 429
        self.email_retry_after = 7200
        self.deliver_email()
        self.email_queue = incidents.EmailQueue(self.email_db)
        self.email_code = 200
        self.assertFalse(self.deliver_email(7199))
        self.assertEqual(len(self.email_requests), 1)
        self.deliver_email(1)
        self.deliver_email()
        self.assertEqual([event["state"] for event in self.sent_mail], ["TRIGGERED", "RESOLVED"])

    def test_email_requires_documented_acceptance_not_generic_success(self):
        self.send_email("TRIGGERED")
        self.send_email("RESOLVED")
        for code, receipt in (
            (202, None),
            (200, {"status": "accepted_by_provider", "incidentId": "missing-message"}),
            (200, {"status": "orphan_recovery"}),
            (200, {"status": []}),
        ):
            self.email_code, self.email_receipt = code, receipt
            self.deliver_email(300)
            self.assertEqual(self.health(self.email_url)[1]["pending"], 2)
            self.assertEqual(self.health(self.email_url)[0], 503)
            self.assertTrue(all(event["state"] == "TRIGGERED" for event in self.email_requests))
        self.email_receipt = None
        self.deliver_email(300)
        self.deliver_email()
        self.assertEqual(self.health(self.email_url)[1]["pending"], 0)

    def test_email_queue_backpressure_and_bounded_receipts_preserve_state(self):
        self.assertEqual(self.send("TRIGGERED", url=self.email_url), 401)
        with patch.object(incidents, "QUEUE_LIMIT", 1):
            self.assertEqual(self.send_email("TRIGGERED"), 202)
            self.assertEqual(self.send_email("RESOLVED"), 503)
            self.assertEqual(self.send_email("TRIGGERED"), 202)
            self.deliver_email()
            self.assertEqual(self.send_email("RESOLVED"), 202)
            self.deliver_email()
        with patch.object(incidents, "HISTORY_LIMIT", 2):
            for state in ("TRIGGERED", "RESOLVED", "TRIGGERED", "RESOLVED"):
                self.send_email(state)
                self.deliver_email()
            with closing(sqlite3.connect(self.email_db)) as db:
                self.assertEqual(db.execute("SELECT count(*) FROM events").fetchone()[0], 2)
        self.email_queue = incidents.EmailQueue(self.email_db)
        self.send_email("RESOLVED")
        self.assertFalse(self.deliver_email())
        self.assertNotIn(ENDPOINT, json.dumps(self.health(self.email_url)))


if __name__ == "__main__":
    unittest.main()
