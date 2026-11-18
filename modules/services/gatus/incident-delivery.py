#!/usr/bin/env python3
"""Persist local Gatus transitions for Notion incidents or ordered email delivery."""

import argparse
from contextlib import closing, contextmanager
from datetime import UTC, datetime
import hashlib
import hmac
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import json
import os
from pathlib import Path
import re
import shutil
import socket
import ssl
import sqlite3
import subprocess
import sys
import tempfile
import threading
import time
from urllib.error import HTTPError, URLError
from urllib.parse import quote, urljoin, urlsplit
from urllib.request import HTTPRedirectHandler, Request, build_opener, urlopen
import uuid

NOTION_API = "https://api.notion.com/v1"
EMAIL_USER_AGENT = "dotfiles-gatus-email/1.0 (+https://github.com/edmundmiller/dotfiles)"
QUEUE_LIMIT = 1000
HISTORY_LIMIT = 100


class DeliveryError(Exception):
    def __init__(self, code, *, retry_after=0, safe_create_retry=False, committed_id=None):
        super().__init__(code)
        self.retry_after = retry_after
        self.safe_create_retry = safe_create_retry
        self.committed_id = committed_id


class Notion:
    def __init__(self, token, data_source, evidence_url):
        self.token = token
        self.data_source = data_source
        self.evidence_url = evidence_url

    def request(self, method, path, body):
        request = Request(
            NOTION_API + path,
            data=json.dumps(body).encode(),
            method=method,
            headers={
                "Authorization": "Bearer " + self.token,
                "Notion-Version": "2026-03-11",
                "Content-Type": "application/json",
            },
        )
        try:
            with urlopen(request, timeout=15) as response:
                return json.load(response)
        except HTTPError as error:
            try:
                with error:
                    detail = json.loads(error.read(65536)).get("additional_data", {})
            except (ValueError, AttributeError):
                detail = {}
            try:
                delay = max(0, int(error.headers.get("Retry-After", "0")))
            except ValueError:
                delay = 0
            raise DeliveryError(
                f"notion-http-{error.code}",
                retry_after=delay,
                safe_create_retry=error.code in {400, 401, 403, 404, 422, 429, 529},
                committed_id=detail.get("committed_resource_id"),
            ) from None
        except (URLError, OSError, ValueError):
            raise DeliveryError("notion-network-or-response") from None

    def find(self, incident_id):
        result = self.request(
            "POST",
            f"/data_sources/{quote(self.data_source, safe='')}/query",
            {
                "filter": {"property": "Incident ID", "rich_text": {"equals": incident_id}},
                "page_size": 2,
            },
        )
        pages = result["results"]
        if len(pages) > 1 or result.get("has_more"):
            raise DeliveryError("duplicate-incident-id", retry_after=300)
        return pages[0]["id"] if pages else None

    def properties(self, incident):
        return {
            "Name": {"title": [{"text": {"content": incident["endpoint"]}}]},
            "Incident ID": {"rich_text": [{"text": {"content": incident["id"]}}]},
            "Status": {"select": {"name": "Resolved" if incident["recovered"] else "Open"}},
            "Detected": {"date": {"start": incident["opened"]}},
            "Recovered": {"date": {"start": incident["recovered"]} if incident["recovered"] else None},
            "Evidence": {"url": self.evidence_url},
        }


class SQLiteStore:
    def __init__(self, path):
        self.path = path

    @contextmanager
    def connect(self):
        with closing(sqlite3.connect(self.path, timeout=5)) as db:
            db.row_factory = sqlite3.Row
            with db:
                yield db


class Incidents(SQLiteStore):
    def __init__(self, path):
        super().__init__(path)
        with self.connect() as db:
            db.execute("""
                CREATE TABLE IF NOT EXISTS incidents (
                    id TEXT PRIMARY KEY, endpoint TEXT NOT NULL, opened TEXT NOT NULL,
                    recovered TEXT, page_id TEXT, attempted INTEGER NOT NULL DEFAULT 0,
                    synced TEXT NOT NULL DEFAULT '', retry_at REAL NOT NULL DEFAULT 0,
                    failures INTEGER NOT NULL DEFAULT 0, error TEXT NOT NULL DEFAULT ''
                )
            """)
            db.execute("""
                CREATE UNIQUE INDEX IF NOT EXISTS open_endpoint
                ON incidents(endpoint) WHERE recovered IS NULL
            """)

    @staticmethod
    def prune(db):
        db.execute("""
            DELETE FROM incidents WHERE id IN (
                SELECT id FROM incidents WHERE recovered IS NOT NULL AND synced = recovered
                ORDER BY opened DESC, rowid DESC LIMIT -1 OFFSET ?
            )
        """, (HISTORY_LIMIT,))

    def accept(self, endpoint, state):
        now = datetime.now(UTC).isoformat()
        with self.connect() as db:
            db.execute("BEGIN IMMEDIATE")
            current = db.execute(
                "SELECT id FROM incidents WHERE endpoint = ? AND recovered IS NULL", (endpoint,)
            ).fetchone()
            if state == "RESOLVED":
                if current:
                    db.execute(
                        "UPDATE incidents SET recovered = ? WHERE id = ?",
                        (now, current["id"]),
                    )
            elif not current:
                pending = db.execute(
                    "SELECT count(*) FROM incidents WHERE recovered IS NULL OR synced != recovered"
                ).fetchone()[0]
                if pending >= QUEUE_LIMIT:
                    raise OverflowError("incident queue full")
                self.prune(db)
                db.execute(
                    "INSERT INTO incidents (id, endpoint, opened) VALUES (?, ?, ?)",
                    (str(uuid.uuid4()), endpoint, now),
                )

    def health(self):
        with self.connect() as db:
            row = db.execute("""
                SELECT count(*) AS pending, coalesce(sum(error != ''), 0) AS errors,
                       min(coalesce(recovered, opened)) AS oldest
                FROM incidents WHERE synced != coalesce(recovered, 'open')
            """).fetchone()
            used = db.execute(
                "SELECT count(*) FROM incidents WHERE recovered IS NULL OR synced != recovered"
            ).fetchone()[0]
        age = max(0, time.time() - datetime.fromisoformat(row["oldest"]).timestamp()) if row["oldest"] else 0
        return {
            "pending": row["pending"],
            "delivery_errors": row["errors"],
            "oldest_pending_seconds": int(age),
            "queue_used": used,
        }

    def deliver_one(self, notion):
        with self.connect() as db:
            row = db.execute("""
                SELECT * FROM incidents
                WHERE synced != coalesce(recovered, 'open') AND retry_at <= ?
                  AND (SELECT coalesce(max(retry_at), 0) FROM incidents
                       WHERE error IN ('notion-http-429', 'notion-http-529')) <= ?
                ORDER BY opened, rowid LIMIT 1
            """, (time.time(), time.time())).fetchone()
        if row is None:
            return False
        page_id = row["page_id"]
        attempted = row["attempted"]
        creating = False
        desired = row["recovered"] or "open"
        try:
            if not page_id:
                page_id = notion.find(row["id"])
                if not page_id:
                    # A timeout may have committed a page without returning its ID.
                    # Keep looking for that ID, never blindly repeat the creation.
                    if attempted:
                        raise DeliveryError("ambiguous-create-needs-reconciliation", retry_after=300)
                    with self.connect() as db:
                        db.execute("UPDATE incidents SET attempted = 1 WHERE id = ?", (row["id"],))
                    attempted = True
                    creating = True
                    try:
                        result = notion.request("POST", "/pages", {
                            "parent": {"data_source_id": notion.data_source},
                            "properties": notion.properties(row),
                            "notifications": {"mode": "silent"},
                        })
                        page_id = result["id"]
                    except DeliveryError as error:
                        if not error.committed_id:
                            raise
                        page_id = error.committed_id
                    creating = False
                # Persist the mapping before any idempotent update or restart.
                with self.connect() as db:
                    db.execute("UPDATE incidents SET page_id = ? WHERE id = ?", (page_id, row["id"]))
            notion.request("PATCH", f"/pages/{quote(page_id, safe='')}", {
                "properties": notion.properties(row),
                "notifications": {"mode": "silent"},
            })
            with self.connect() as db:
                db.execute(
                    "UPDATE incidents SET synced = ?, error = '', failures = 0, retry_at = 0 WHERE id = ?",
                    (desired, row["id"]),
                )
                self.prune(db)
        except DeliveryError as error:
            delay = max(error.retry_after, min(300, 5 * 2 ** min(row["failures"], 6)))
            with self.connect() as db:
                db.execute(
                    "UPDATE incidents SET attempted = ?, error = ?, failures = failures + 1, retry_at = ? WHERE id = ?",
                    (attempted and not (creating and error.safe_create_retry), str(error), time.time() + delay, row["id"]),
                )
            # Only fixed categories, never response bodies, credentials or HA data.
            print(f"Notion incident delivery: {error}", flush=True)
        return True


class CloudflareEmail:
    def __init__(self, token, url, *, require_new_acceptance=False):
        self.token = token
        self.url = url
        self.require_new_acceptance = require_new_acceptance

    def send(self, endpoint, state):
        request = Request(self.url, data=json.dumps({"endpoint": endpoint, "state": state}).encode(), headers={
            "Authorization": "Bearer " + self.token,
            "Content-Type": "application/json",
            "User-Agent": EMAIL_USER_AGENT,
        })
        try:
            with urlopen(request, timeout=15) as response:
                result = json.load(response)
                status = result.get("status") if isinstance(result, dict) else None
                if response.status != 200 or status not in ("accepted_by_provider", "duplicate", "orphan_recovery"):
                    raise DeliveryError("email-invalid-receipt")
                if self.require_new_acceptance and status != "accepted_by_provider":
                    raise DeliveryError("email-acceptance-needs-reconciliation")
                if status == "orphan_recovery" and state != "RESOLVED":
                    raise DeliveryError("email-invalid-receipt")
                if status == "accepted_by_provider" and not all(
                    isinstance(result.get(key), str) and result[key] for key in ("incidentId", "messageId")
                ):
                    raise DeliveryError("email-invalid-receipt")
        except HTTPError as error:
            with error:
                try:
                    retry = max(0, int(error.headers.get("Retry-After", "0")))
                except ValueError:
                    retry = 0
                raise DeliveryError(f"email-http-{error.code}", retry_after=retry) from None
        except (URLError, OSError, ValueError):
            raise DeliveryError("email-network-or-response") from None


class EmailQueue(SQLiteStore):
    def __init__(self, path):
        super().__init__(path)
        with self.connect() as db:
            db.execute("""
                CREATE TABLE IF NOT EXISTS endpoints (
                    endpoint TEXT PRIMARY KEY, state TEXT NOT NULL
                )
            """)
            db.execute("""
                CREATE TABLE IF NOT EXISTS events (
                    seq INTEGER PRIMARY KEY, endpoint TEXT NOT NULL, state TEXT NOT NULL,
                    received TEXT NOT NULL, delivered INTEGER NOT NULL DEFAULT 0,
                    retry_at REAL NOT NULL DEFAULT 0, failures INTEGER NOT NULL DEFAULT 0,
                    error TEXT NOT NULL DEFAULT ''
                )
            """)

    def accept(self, endpoint, state):
        with self.connect() as db:
            db.execute("BEGIN IMMEDIATE")
            current = db.execute("SELECT state FROM endpoints WHERE endpoint = ?", (endpoint,)).fetchone()
            if state == (current["state"] if current else "RESOLVED"):
                return
            if db.execute("SELECT count(*) FROM events WHERE delivered = 0").fetchone()[0] >= QUEUE_LIMIT:
                raise OverflowError("email queue full")
            db.execute("INSERT INTO events (endpoint, state, received) VALUES (?, ?, ?)",
                       (endpoint, state, datetime.now(UTC).isoformat()))
            db.execute("INSERT OR REPLACE INTO endpoints VALUES (?, ?)", (endpoint, state))

    def health(self):
        with self.connect() as db:
            row = db.execute("""
                SELECT count(*) AS pending, coalesce(sum(error != ''), 0) AS errors,
                       min(received) AS oldest FROM events WHERE delivered = 0
            """).fetchone()
        age = max(0, time.time() - datetime.fromisoformat(row["oldest"]).timestamp()) if row["oldest"] else 0
        return {
            "pending": row["pending"], "delivery_errors": row["errors"],
            "oldest_pending_seconds": int(age), "queue_used": row["pending"],
        }

    def deliver_one(self, sender):
        with self.connect() as db:
            # Select the head before checking its retry time: recovery must not pass it.
            row = db.execute("SELECT * FROM events WHERE delivered = 0 ORDER BY seq LIMIT 1").fetchone()
        if row is None or row["retry_at"] > time.time() or row["error"] == "email-http-409":
            return False
        try:
            sender.send(row["endpoint"], row["state"])
            with self.connect() as db:
                db.execute("UPDATE events SET delivered = 1, error = '' WHERE seq = ?", (row["seq"],))
                db.execute("""
                    DELETE FROM events WHERE seq IN (
                        SELECT seq FROM events WHERE delivered = 1 ORDER BY seq DESC LIMIT -1 OFFSET ?
                    )
                """, (HISTORY_LIMIT,))
        except DeliveryError as error:
            delay = max(error.retry_after, min(300, 5 * 2 ** min(row["failures"], 6)))
            with self.connect() as db:
                db.execute("UPDATE events SET error = ?, failures = failures + 1, retry_at = ? WHERE seq = ?",
                           (str(error), time.time() + delay, row["seq"]))
            print(f"Email delivery: {error}", flush=True)
        return True


def make_server(store, token, endpoints, port):
    wake = threading.Event()

    class Handler(BaseHTTPRequestHandler):
        timeout = 5

        def log_message(self, *_args):
            pass

        def reply(self, status, body):
            encoded = json.dumps(body).encode()
            self.send_response(status)
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(encoded)))
            self.end_headers()
            self.wfile.write(encoded)

        def do_GET(self):
            if self.path != "/health":
                return self.reply(404, {})
            health = store.health()
            failed = health["delivery_errors"] or health["oldest_pending_seconds"] >= 300 or health["queue_used"] >= QUEUE_LIMIT
            self.reply(503 if failed else 200, health)

        def do_POST(self):
            if self.path != "/events":
                return self.reply(404, {})
            if not hmac.compare_digest(self.headers.get("Authorization", "").encode(), ("Bearer " + token).encode()):
                return self.reply(401, {})
            try:
                size = int(self.headers.get("Content-Length", "0"))
                if not 0 < size <= 8192 or self.headers.get_content_type() != "application/json":
                    return self.reply(400, {})
                payload = json.loads(self.rfile.read(size))
                if (
                    not isinstance(payload, dict)
                    or set(payload) != {"endpoint", "state"}
                    or not isinstance(payload["endpoint"], str)
                    or payload["endpoint"] not in endpoints
                    or payload["state"] not in ("TRIGGERED", "RESOLVED")
                ):
                    return self.reply(400, {})
                store.accept(payload["endpoint"], payload["state"])
            except (ValueError, UnicodeError):
                return self.reply(400, {})
            except (OverflowError, sqlite3.Error):
                return self.reply(503, {})
            wake.set()
            self.reply(202, {"queued": True})

    server = ThreadingHTTPServer(("127.0.0.1", port), Handler)
    server.daemon_threads = True
    return server, wake


def require_fresh_producer(database=Path("/var/lib/gatus/data.db")):
    # Inspect only a private physical snapshot. Opening the live SQLite file
    # can modify its shared-memory sidecar even through a read-only connection.
    files = [Path(str(database) + suffix) for suffix in ("", "-wal", "-journal")]

    def versions():
        result = []
        for path in files:
            if path.exists():
                info = path.stat()
                result.append((info.st_ino, info.st_size, info.st_mtime_ns, info.st_ctime_ns))
            else:
                result.append(None)
        return result

    before = versions()
    if before[0] is None:
        raise DeliveryError("acceptance-producer-database-unavailable")
    with tempfile.TemporaryDirectory(prefix="gatus-email-preflight-") as temporary:
        snapshot = Path(temporary) / "data.db"
        for path, version, suffix in zip(files, before, ("", "-wal", "-journal")):
            if version is not None:
                shutil.copyfile(path, Path(str(snapshot) + suffix))
        if versions() != before:
            raise DeliveryError("acceptance-producer-snapshot-changed")
        with closing(sqlite3.connect(snapshot)) as db:
            if db.execute("PRAGMA quick_check").fetchone()[0] != "ok":
                raise DeliveryError("acceptance-producer-snapshot-invalid")
            # First-enable test only. Even a removed/resolved durable route
            # requires separate reconciliation; never discard retained state.
            if db.execute("SELECT count(*) FROM sqlite_master WHERE name = 'alert_delivery_state'").fetchone()[0]:
                raise DeliveryError("acceptance-retained-producer-state-needs-reconciliation")


def require_email_test_preconditions():
    if socket.gethostname() != "nuc" or os.geteuid() != 0:
        raise DeliveryError("acceptance-requires-root-on-nuc")
    unit = subprocess.run(
        ["systemctl", "show", "gatus-email.service", "-p", "LoadState", "--value"],
        capture_output=True, text=True, timeout=5,
    )
    if unit.returncode not in (0, 4) or unit.stdout.strip() != "not-found":
        raise DeliveryError("acceptance-requires-production-email-absent")
    # The workflow serializes this operation against deployments. Do not change
    # the production producer or its journal to manufacture a test transition.
    if "gatus-email" in Path("/run/gatus/config.yaml").read_text():
        raise DeliveryError("acceptance-requires-production-route-absent")
    production = Path("/var/lib/gatus-email/events.sqlite")
    if production.exists() or Path(str(production) + "-wal").exists():
        # Do not open a production SQLite journal, even read-only: WAL readers
        # can create or update shared-memory sidecars. Reconcile it separately.
        raise DeliveryError("acceptance-existing-production-journal-needs-reconciliation")
    require_fresh_producer()
    for url in ("http://127.0.0.1:8084/health", "http://127.0.0.1:8124/health"):
        with urlopen(url, timeout=5) as response:
            if response.status != 200:
                raise DeliveryError("acceptance-requires-healthy-monitoring")


def email_acceptance_test(
    directory=Path("/var/lib/gatus-email-acceptance"),
    worker_url="https://mill-docs-agents.edmund-a-miller.workers.dev/api/monitoring/gatus-email",
    token_file=Path("/run/agenix/gatus-email-worker"),
    ingest_file=Path("/run/agenix/gatus-email-ingest"),
):
    """One synthetic pair before activation; retain intent and FIFO on any failure."""
    require_email_test_preconditions()
    family_revision = os.environ.get("GATUS_EMAIL_TEST_FAMILY_REVISION", "")
    if not re.fullmatch(r"[0-9a-f]{40}", family_revision):
        raise DeliveryError("acceptance-requires-verified-family-revision")
    for path in (token_file, ingest_file):
        info = path.stat()
        if info.st_uid != os.geteuid() or info.st_mode & 0o077:
            raise DeliveryError("acceptance-requires-private-credentials")
    token, ingest = token_file.read_text().strip(), ingest_file.read_text().strip()
    if not token or not ingest:
        raise DeliveryError("acceptance-requires-existing-credentials")
    directory.mkdir(mode=0o700, parents=True, exist_ok=True)
    if directory.stat().st_uid != os.geteuid() or directory.stat().st_mode & 0o077:
        raise DeliveryError("acceptance-requires-private-journal")
    if (directory / "events.sqlite").exists():
        raise DeliveryError("acceptance-existing-test-journal-needs-reconciliation")
    # Exclusive creation is durable before any external request. Never erase or
    # replay a previous claim, including a process crash before a response.
    with (directory / "claim.jsonl").open("x") as claim:
        claim.write(json.dumps({"synthetic": True, "family_revision": family_revision,
                                "started": datetime.now(UTC).isoformat()}) + "\n")
        claim.flush()
        os.fsync(claim.fileno())
    for path in (directory.parent, directory):
        directory_fd = os.open(path, os.O_RDONLY | os.O_DIRECTORY)
        try:
            os.fsync(directory_fd)
        finally:
            os.close(directory_fd)
    endpoint = "Smart Home: Home Assistant Runtime"
    for authenticated, expected in ((False, 401), (True, 400)):
        headers = {"Content-Type": "application/json", "User-Agent": EMAIL_USER_AGENT}
        if authenticated:
            headers["Authorization"] = "Bearer " + token
        request = Request(worker_url, data=json.dumps({"endpoint": endpoint, "state": "INVALID"}).encode(), headers=headers)
        try:
            with urlopen(request, timeout=15):
                raise DeliveryError("acceptance-invalid-state-unexpectedly-accepted")
        except HTTPError as error:
            with error:
                if error.code != expected:
                    raise DeliveryError("acceptance-authentication-probe-failed") from None
    queue = EmailQueue(directory / "events.sqlite")
    sender = CloudflareEmail(token, worker_url, require_new_acceptance=True)
    server, _wake = make_server(queue, ingest, [endpoint], 0)
    serving = threading.Thread(target=server.serve_forever, daemon=True)
    serving.start()
    try:
        for state in ("TRIGGERED", "RESOLVED"):
            require_email_test_preconditions()
            request = Request(f"http://127.0.0.1:{server.server_port}/events",
                              data=json.dumps({"endpoint": endpoint, "state": state}).encode(), headers={
                                  "Content-Type": "application/json", "Authorization": "Bearer " + ingest,
                              })
            with urlopen(request, timeout=5) as response:
                if response.status != 202:
                    raise DeliveryError("acceptance-local-ingest-failed")
            queue.deliver_one(sender)
            if queue.health()["pending"] or queue.health()["delivery_errors"]:
                raise DeliveryError("acceptance-delivery-unconfirmed-no-replay")
            with (directory / "claim.jsonl").open("a") as claim:
                claim.write(json.dumps({"synthetic": True, "state": state,
                                        "receiver_acknowledged": datetime.now(UTC).isoformat()}) + "\n")
                claim.flush()
                os.fsync(claim.fileno())
        print(json.dumps({"synthetic": True, "receiver_acknowledged_pair": True,
                          "provider_receipt_correlation": "requires-family-evidence", "inbox_delivery": "unverified"}))
    finally:
        server.shutdown()
        server.server_close()
        serving.join(timeout=5)


def email_preflight_diagnostic(
    directory=Path("/var/lib/gatus-email-diagnostic"),
    prior_directory=Path("/var/lib/gatus-email-acceptance"),
    worker_url="https://mill-docs-agents.edmund-a-miller.workers.dev/api/monitoring/gatus-email",
    token_file=Path("/run/agenix/gatus-email-worker"),
    prior_diagnostic_directory=None,
):
    """One separately approved diagnostic; never resume the failed acceptance."""
    require_email_test_preconditions()
    prior_file = prior_directory / "claim.jsonl"
    if prior_file.stat().st_size > 4096 or any(
        (prior_directory / ("events.sqlite" + suffix)).exists() for suffix in ("", "-wal", "-shm", "-journal")
    ):
        raise DeliveryError("diagnostic-prior-intent-needs-reconciliation")
    prior_bytes = prior_file.read_bytes()
    prior = [json.loads(line) for line in prior_bytes.splitlines()]
    if (len(prior) != 1 or not isinstance(prior[0], dict)
            or set(prior[0]) != {"synthetic", "family_revision", "started"}
            or prior[0]["synthetic"] is not True):
        raise DeliveryError("diagnostic-prior-intent-needs-reconciliation")
    reconciled_diagnostic = {}
    if prior_diagnostic_directory is not None:
        previous_file = prior_diagnostic_directory / "claim.jsonl"
        info = prior_diagnostic_directory.stat()
        if (info.st_uid != os.geteuid() or info.st_mode & 0o077
                or previous_file.stat().st_size > 8192
                or any((prior_diagnostic_directory / ("events.sqlite" + suffix)).exists()
                       for suffix in ("", "-wal", "-shm", "-journal"))):
            raise DeliveryError("diagnostic-prior-probe-needs-reconciliation")
        previous_bytes = previous_file.read_bytes()
        previous = [json.loads(line) for line in previous_bytes.splitlines()]
        if (len(previous) != 4 or not all(isinstance(event, dict) for event in previous)
                or previous[0].get("diagnostic_only") is not True
                or previous[0].get("prior_intent_sha256") != hashlib.sha256(prior_bytes).hexdigest()):
            raise DeliveryError("diagnostic-prior-probe-needs-reconciliation")
        intent, response_headers, response = previous[1:]
        expected_url = urlsplit(worker_url)
        if (intent.get("event") != "request_intent" or intent.get("method") != "POST"
                or intent.get("url") != worker_url or intent.get("content_type") != "application/json"
                or response_headers.get("event") != "response_headers" or "event" in response
                or not isinstance(intent.get("correlation_id"), str)
                or not re.fullmatch(r"[0-9a-f-]{36}", intent["correlation_id"])
                or any(event.get("phase") != "unauthenticated"
                       or event.get("correlation_id") != intent["correlation_id"] for event in previous[1:])
                or any(event.get("status") != 403 or event.get("content_type") != "text/plain"
                       or event.get("error") != "unclassified"
                       or event.get("final_url") != {"scheme": expected_url.scheme, "host": expected_url.hostname,
                                                     "path": expected_url.path, "port": expected_url.port}
                       for event in previous[2:])
                or not isinstance(response.get("cf_ray"), str)
                or not re.fullmatch(r"[0-9a-fA-F]{16,32}(?:-[A-Z0-9]{2,8})?", response["cf_ray"])
                or response_headers.get("cf_ray") != response["cf_ray"]):
            raise DeliveryError("diagnostic-prior-probe-needs-reconciliation")
        reconciled_diagnostic["prior_diagnostic_sha256"] = hashlib.sha256(previous_bytes).hexdigest()
    family_revision = os.environ.get("GATUS_EMAIL_TEST_FAMILY_REVISION", "")
    family_version = os.environ.get("GATUS_EMAIL_DIAGNOSTIC_FAMILY_VERSION", "")
    run_id = os.environ.get("GATUS_EMAIL_DIAGNOSTIC_RUN_ID", "")
    if (not re.fullmatch(r"[0-9a-f]{40}", family_revision)
            or not re.fullmatch(r"[0-9a-f]{8}(?:-[0-9a-f]{4}){3}-[0-9a-f]{12}", family_version)
            or not re.fullmatch(r"[0-9]{1,20}", run_id)):
        raise DeliveryError("diagnostic-requires-exact-readiness-and-run")
    info = token_file.stat()
    if info.st_uid != os.geteuid() or info.st_mode & 0o077:
        raise DeliveryError("diagnostic-requires-private-credential")
    token = token_file.read_text().strip()
    if not token:
        raise DeliveryError("diagnostic-requires-existing-credential")
    directory.mkdir(mode=0o700, parents=True, exist_ok=True)
    info = directory.stat()
    if info.st_uid != os.geteuid() or info.st_mode & 0o077:
        raise DeliveryError("diagnostic-requires-private-journal")

    class NoRedirect(HTTPRedirectHandler):
        def redirect_request(self, req, fp, code, msg, headers, newurl):
            return None

    opener = build_opener(NoRedirect())
    expected_url = urlsplit(worker_url)

    def describe_url(value):
        try:
            parsed = urlsplit(urljoin(worker_url, value))
            return {key: actual if actual == expected else "other" for key, actual, expected in (
                ("scheme", parsed.scheme, expected_url.scheme),
                ("host", parsed.hostname, expected_url.hostname),
                ("path", parsed.path, expected_url.path),
                ("port", parsed.port, expected_url.port),
            )}
        except ValueError:
            return {"scheme": "invalid", "host": "invalid", "path": "invalid"}

    with (directory / "claim.jsonl").open("x") as claim:
        def record(event):
            event["at"] = datetime.now(UTC).isoformat()
            line = json.dumps(event)
            claim.write(line + "\n")
            claim.flush()
            os.fsync(claim.fileno())
            print(line, flush=True)

        record({"diagnostic_only": True, "family_revision": family_revision,
                "family_version": family_version, "run_id": run_id,
                "prior_intent_sha256": hashlib.sha256(prior_bytes).hexdigest(),
                "user_agent": EMAIL_USER_AGENT, **reconciled_diagnostic})
        for path in (directory.parent, directory):
            descriptor = os.open(path, os.O_RDONLY | os.O_DIRECTORY)
            try:
                os.fsync(descriptor)
            finally:
                os.close(descriptor)
        for phase, expected, classification in (("unauthenticated", 401, "unauthorized"),
                                                 ("authenticated", 400, "invalid_transition")):
            require_email_test_preconditions()
            correlation = str(uuid.uuid4())
            record({"phase": phase, "correlation_id": correlation, "event": "request_intent",
                    "method": "POST", "url": worker_url, "content_type": "application/json"})
            headers = {"Content-Type": "application/json", "User-Agent": EMAIL_USER_AGENT}
            if phase == "authenticated":
                headers["Authorization"] = "Bearer " + token
            request = Request(worker_url, method="POST", headers=headers, data=json.dumps({
                "endpoint": "Smart Home: Home Assistant Runtime", "state": "INVALID",
            }).encode())
            try:
                try:
                    response = opener.open(request, timeout=15)
                except HTTPError as error:
                    response = error
            except (URLError, OSError) as error:
                reason = error.reason if isinstance(error, URLError) else error
                category = ("tls" if isinstance(reason, ssl.SSLError) else
                            "timeout" if isinstance(reason, TimeoutError) else
                            "dns" if isinstance(reason, socket.gaierror) else "network")
                record({"phase": phase, "correlation_id": correlation, "network_error": category})
                raise DeliveryError("diagnostic-network-failure-no-replay") from None
            with response:
                media = response.headers.get_content_type()
                event = {"phase": phase, "correlation_id": correlation, "status": response.status,
                         "final_url": describe_url(response.geturl()),
                         "content_type": media if media in ("application/json", "text/html", "text/plain") else "other",
                         "error": "unclassified"}
                ray = response.headers.get("CF-Ray", "")
                if re.fullmatch(r"[0-9a-fA-F]{16,32}(?:-[A-Z0-9]{2,8})?", ray):
                    event["cf_ray"] = ray
                record({**event, "event": "response_headers"})
                if 300 <= response.status < 400:
                    event["redirect"] = describe_url(response.headers.get("Location", ""))
                elif media == "application/json":
                    try:
                        body = response.read(4097)
                    except (OSError, URLError):
                        record({"phase": phase, "correlation_id": correlation, "network_error": "response_read"})
                        raise DeliveryError("diagnostic-response-read-failed-no-replay") from None
                    try:
                        result = json.loads(body) if len(body) <= 4096 else None
                        detail = result.get("error") if isinstance(result, dict) and set(result) == {"error"} else None
                        if isinstance(detail, str) and detail in (
                            "unauthorized", "invalid_transition", "unsupported_media_type", "disabled", "method_not_allowed",
                        ):
                            event["error"] = detail
                    except (ValueError, UnicodeError):
                        pass
                record(event)
                if response.status != expected or event["error"] != classification:
                    raise DeliveryError("diagnostic-unexpected-response-no-replay")
        record({"diagnostic_only": True, "expected_rejections_confirmed": True,
                "valid_transitions_sent": 0, "pair_retry_authorized": False})


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--state-file", required=True)
    parser.add_argument("--token-file", required=True)
    parser.add_argument("--ingest-token-file", required=True)
    parser.add_argument("--data-source")
    parser.add_argument("--evidence-url")
    parser.add_argument("--email-url")
    parser.add_argument("--endpoints-file", required=True)
    parser.add_argument("--port", type=int, default=8125)
    args = parser.parse_args()
    token = Path(args.token_file).read_text().strip()
    ingest_token = Path(args.ingest_token_file).read_text().strip()
    if not token or not ingest_token:
        parser.error("nonempty runtime credentials required")
    if args.email_url:
        store = EmailQueue(args.state_file)
        sender = CloudflareEmail(token, args.email_url)
    else:
        if not args.data_source or not args.evidence_url:
            parser.error("Notion requires data source and evidence URL")
        store = Incidents(args.state_file)
        sender = Notion(token, args.data_source, args.evidence_url)
    endpoints = json.loads(Path(args.endpoints_file).read_text())
    server, wake = make_server(store, ingest_token, endpoints, args.port)
    serving = threading.Thread(target=server.serve_forever, daemon=True)
    serving.start()
    try:
        while serving.is_alive():
            wake.clear()
            if not store.deliver_one(sender):
                wake.wait(5)
        raise RuntimeError("incident HTTP receiver stopped")
    finally:
        server.shutdown()
        server.server_close()


if __name__ == "__main__":
    if sys.argv[1:] in (["acceptance-test"], ["email-diagnostic"], ["email-client-diagnostic"]):
        try:
            if sys.argv[1:] == ["email-client-diagnostic"]:
                email_preflight_diagnostic(
                    directory=Path("/var/lib/gatus-email-client-diagnostic"),
                    prior_diagnostic_directory=Path("/var/lib/gatus-email-diagnostic"),
                )
            elif sys.argv[1:] == ["email-diagnostic"]:
                email_preflight_diagnostic()
            else:
                email_acceptance_test()
        except Exception as error:
            # Never include HTTP bodies, runtime config or credentials in logs.
            reason = str(error) if isinstance(error, DeliveryError) else type(error).__name__
            print(json.dumps({"synthetic": True, "result": "blocked-no-replay", "reason": reason}))
            sys.exit(1)
    else:
        main()
