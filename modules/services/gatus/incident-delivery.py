#!/usr/bin/env python3
"""Persist local Gatus transitions for Notion incidents or ordered email delivery."""

import argparse
from contextlib import closing, contextmanager
from datetime import UTC, datetime
import hmac
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import json
from pathlib import Path
import sqlite3
import threading
import time
from urllib.error import HTTPError, URLError
from urllib.parse import quote
from urllib.request import Request, urlopen
import uuid

NOTION_API = "https://api.notion.com/v1"
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
    def __init__(self, token, url):
        self.token = token
        self.url = url

    def send(self, endpoint, state):
        request = Request(self.url, data=json.dumps({"endpoint": endpoint, "state": state}).encode(), headers={
            "Authorization": "Bearer " + self.token,
            "Content-Type": "application/json",
        })
        try:
            with urlopen(request, timeout=15) as response:
                result = json.load(response)
                status = result.get("status") if isinstance(result, dict) else None
                if response.status != 200 or status not in ("accepted_by_provider", "duplicate", "orphan_recovery"):
                    raise DeliveryError("email-invalid-receipt")
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
    main()
