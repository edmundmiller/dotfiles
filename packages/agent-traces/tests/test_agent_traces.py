from __future__ import annotations

import hashlib
import json
import os
import sqlite3
import subprocess
import tempfile
import unittest
from datetime import UTC, datetime
from pathlib import Path
from unittest import mock

from agent_traces.ingest import ingest_candidates, writer_lock
from agent_traces.schema import ICEBERG_SCHEMA, PARTITION_SPEC
from agent_traces.sources import Candidate, amp_candidates, opencode_candidates, stable_read


class AgentTracesTests(unittest.TestCase):
    def test_schema_and_partition_contract(self) -> None:
        self.assertEqual(
            [field.name for field in ICEBERG_SCHEMA.fields],
            [
                "source", "native_id", "version_hash", "observed_at",
                "native_modified_at", "started_at", "updated_at", "native_size",
                "native_format", "native_locator", "title", "cwd", "model",
                "normalization_status", "record_count", "diagnostics_json",
                "trajectory_json", "native_bytes",
            ],
        )
        self.assertEqual([field.name for field in PARTITION_SPEC.fields], ["source", "native_modified_day"])

    def test_stable_read_retries_once(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory, "session.jsonl")
            path.write_bytes(b"first")
            real_stat = path.stat
            stats = [real_stat(), real_stat(), real_stat(), real_stat()]
            stats[1] = os.stat_result((*stats[1][:6], stats[1].st_size + 1, *stats[1][7:]))
            with mock.patch("agent_traces.sources.os.stat", side_effect=stats):
                self.assertEqual(stable_read(path), b"first")

    def test_opencode_reads_wal_and_is_deterministic(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory, "opencode.db")
            writer = sqlite3.connect(path)
            writer.executescript("""
                PRAGMA journal_mode=WAL;
                CREATE TABLE session (id TEXT PRIMARY KEY, directory TEXT, title TEXT, time_created INTEGER, time_updated INTEGER, data TEXT);
                CREATE TABLE message (id TEXT PRIMARY KEY, session_id TEXT, time_created INTEGER, time_updated INTEGER, data TEXT);
                CREATE TABLE part (id TEXT PRIMARY KEY, message_id TEXT, session_id TEXT, time_created INTEGER, time_updated INTEGER, data TEXT);
            """)
            writer.execute("INSERT INTO session VALUES (?,?,?,?,?,?)", ("s1", "/tmp/project", "Test", 1000, 2000, '{}'))
            writer.execute("INSERT INTO message VALUES (?,?,?,?,?)", ("m1", "s1", 1100, 1200, '{"role":"user"}'))
            writer.execute("INSERT INTO part VALUES (?,?,?,?,?,?)", ("p1", "m1", "s1", 1100, 1200, '{"type":"text","text":"hello"}'))
            writer.commit()
            first = list(opencode_candidates(path))[0].read()
            second = list(opencode_candidates(path))[0].read()
            writer.close()
            self.assertEqual(first, second)
            self.assertEqual(json.loads(first)["messages"][0]["parts"][0]["id"], "p1")

    @mock.patch("agent_traces.sources.shutil.which", return_value="/bin/amp")
    @mock.patch("agent_traces.sources.subprocess.run")
    def test_amp_pages_and_exports(self, run: mock.Mock, _which: mock.Mock) -> None:
        pages = [
            subprocess.CompletedProcess([], 0, stdout=json.dumps([{"id": "a", "updated": "2026-07-27T00:00:00Z"}]), stderr=""),
            subprocess.CompletedProcess([], 0, stdout="[]", stderr=""),
            subprocess.CompletedProcess([], 0, stdout=json.dumps({"id": "a", "messages": []}), stderr=""),
        ]
        run.side_effect = pages
        candidates = list(amp_candidates(page_size=1))
        self.assertEqual([candidate.native_id for candidate in candidates], ["a"])
        self.assertEqual(json.loads(candidates[0].read())["id"], "a")
        self.assertEqual(run.call_count, 3)

    def test_missing_sources_are_noop(self) -> None:
        from agent_traces.sources import discover_candidates
        with tempfile.TemporaryDirectory() as home:
            with mock.patch.dict(os.environ, {"HOME": home}, clear=False), mock.patch("shutil.which", return_value=None):
                self.assertEqual(list(discover_candidates()), [])

    def test_writer_lock_rejects_second_writer(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory, "lock")
            with writer_lock(path):
                with self.assertRaisesRegex(RuntimeError, "already running"):
                    with writer_lock(path):
                        pass

    def test_local_catalog_is_idempotent_and_immutable(self) -> None:
        from pyiceberg.catalog import load_catalog

        with tempfile.TemporaryDirectory() as directory:
            catalog = load_catalog(
                "test",
                type="sql",
                uri=f"sqlite:///{directory}/catalog.db",
                warehouse=f"file://{directory}/warehouse",
            )
            original = b'{"type":"session","id":"fixture"}\n'
            candidate = fixture_candidate(original)
            first = ingest_candidates(catalog, [candidate], observed_at=datetime.now(UTC))
            table = catalog.load_table("agent_traces.sessions")
            first_snapshot = table.current_snapshot().snapshot_id
            second = ingest_candidates(catalog, [candidate], observed_at=datetime.now(UTC))
            table.refresh()
            self.assertEqual((first.inserted, second.inserted), (1, 0))
            self.assertEqual(table.current_snapshot().snapshot_id, first_snapshot)

            changed = fixture_candidate(original + b'{"type":"message"}\n')
            third = ingest_candidates(catalog, [changed], observed_at=datetime.now(UTC))
            self.assertEqual(third.inserted, 1)
            self.assertEqual(catalog.load_table("agent_traces.sessions").scan().to_arrow().num_rows, 2)

    def test_hash_native_bytes_and_raw_only_diagnostics(self) -> None:
        from pyiceberg.catalog import load_catalog

        with tempfile.TemporaryDirectory() as directory:
            catalog = load_catalog("test", type="sql", uri=f"sqlite:///{directory}/catalog.db", warehouse=f"file://{directory}/warehouse")
            native = b"not valid"
            result = ingest_candidates(catalog, [fixture_candidate(native, fail=True)], observed_at=datetime.now(UTC))
            row = catalog.load_table("agent_traces.sessions").scan().to_arrow().to_pylist()[0]
            self.assertEqual(result.failed, 1)
            self.assertEqual(row["version_hash"], hashlib.sha256(native).hexdigest())
            self.assertEqual(row["native_bytes"], native)
            self.assertEqual(row["normalization_status"], "raw_only")
            self.assertTrue(json.loads(row["diagnostics_json"])[0]["message"])


def fixture_candidate(native: bytes, fail: bool = False) -> Candidate:
    def normalize(_: bytes) -> list[dict[str, object]]:
        if fail:
            raise ValueError("fixture normalization failed")
        return [{"type": "meta", "source": "codex", "id": "fixture"}]

    return Candidate(
        source="codex",
        native_id="fixture",
        native_format="jsonl",
        native_locator="~/.codex/sessions/fixture.jsonl",
        native_modified_at=datetime(2026, 7, 27, tzinfo=UTC),
        native_size=len(native),
        read=lambda: native,
        normalize=normalize,
    )


if __name__ == "__main__":
    unittest.main()
