"""Sanitized snapshot contract, cache and bounded display tests."""
from datetime import datetime, timedelta, timezone
import importlib.machinery
import importlib.util
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from zoneinfo import ZoneInfo

SCRIPT = Path(__file__).with_name("displayctl")
loader = importlib.machinery.SourceFileLoader("displayctl", str(SCRIPT))
display = importlib.util.module_from_spec(importlib.util.spec_from_loader(loader.name, loader))
loader.exec_module(display)
NOW = datetime(2026, 9, 7, 1, 30, tzinfo=timezone.utc)


def task(title, contexts=(), raw="todo", completed=None):
    return dict(id=title, path=f"Tasks/{title}.md", title=title,
                status="completed" if raw == "done" else "cancelled" if raw == "cancelled" else "pending",
                rawStatus=raw, contexts=list(contexts), projects=[], tags=[], due=None,
                scheduled=None, completedDate=completed)


def fixture(state="normal"):
    snapshot = dict(sourceVault="/example/TaskNotes", observedAt=NOW.isoformat(), tasks=[
        task("Plan the weekend", ["Home"]), task("Send project outline", ["Work"]),
        task("Book a checkup"), task("Submit the report", raw="done", completed="2026-09-06"),
        task("Cancelled item", raw="cancelled", completed="2026-09-06"),
    ])
    if state == "stale":
        snapshot["observedAt"] = (NOW - timedelta(hours=2)).isoformat()
    elif state == "error":
        snapshot["error"] = "Source unavailable. Showing last known tasks."
    elif state == "empty":
        snapshot["tasks"] = []
    elif state == "unavailable":
        snapshot.update(observedAt=None, tasks=[], error="Source unavailable. Check source access.")
    elif state == "overloaded":
        snapshot["tasks"] += [task(f"Idea {i:04}", ["Ideas"], "backlog") for i in range(1842)]
        snapshot["tasks"] += [task(f"Unscheduled todo {i:03}", ["Work"]) for i in range(368)]
        snapshot["tasks"] += [task("Await supplier reply", ["Work"], "waiting"), task("Read reference", ["Writing"])]
    elif state == "real_scale":
        snapshot["tasks"] = [task(f"Idea {i:04}", ["Ideas"], "backlog") for i in range(2032)]
        snapshot["tasks"] += [task(f"Unsorted capture {i:03}") for i in range(209)]
        snapshot["tasks"] += [task(f"Review [long reference title {i:03}](https://example.com/reference) and write summary", [f"Context {i % 59:02}"], "waiting" if i % 5 == 0 else "todo") for i in range(450)]
        snapshot["tasks"] += [task("Finished item", raw="done", completed="2026-09-06")]
    return snapshot


class TaskTests(unittest.TestCase):
    def payload(self, value):
        return display._task_payload(value, NOW, ZoneInfo("America/Chicago"), 900)

    def test_local_day_terminal_semantics_and_stable_groups(self):
        value = fixture()
        value["tasks"] += [task("Instant today", raw="done", completed="2026-09-07T00:30:00Z"),
                           task("Tomorrow locally", raw="done", completed="2026-09-07T06:00:00Z")]
        result = self.payload(value)
        self.assertEqual(result["task_day"], "2026-09-06")
        self.assertEqual(result["task_done"]["count"], 2)
        self.assertEqual(result["task_unclassified"]["count"], 1)
        value["tasks"].reverse()
        self.assertEqual(result, self.payload(value))

    def test_overload_is_bounded_without_hiding_backlog_or_unclassified(self):
        result = self.payload(fixture("overloaded"))
        self.assertEqual(result["task_backlog_count"], 1842)
        self.assertEqual(result["task_active_count"], 373)
        self.assertEqual(result["task_more_groups"], 1)
        self.assertEqual(result["task_unclassified"]["count"], 1)
        self.assertLess(len(json.dumps(result)), 2000)
        work = fixture()
        work["tasks"] = [task("Await reply", ["Work"], "waiting")]
        self.assertEqual(self.payload(work)["task_groups"][0]["titles"], ["[waiting] Await reply"])

    def test_honest_states(self):
        for state, label in (("normal", "OBSERVED"), ("stale", "STALE / LAST KNOWN"),
                             ("error", "ERROR / LAST KNOWN"), ("unavailable", "ERROR / NO OBSERVATION")):
            result = self.payload(fixture(state))
            self.assertEqual(result["task_state"], label)
            self.assertFalse(result["task_empty"])
        self.assertTrue(self.payload(fixture("empty"))["task_empty"])

    def test_first_context_only_and_real_scale_counts(self):
        value = fixture()
        value["tasks"] = [task("Shared", [" Work ", "Home", "Home"]), task("Blank", ["  "])]
        result = self.payload(value)
        self.assertEqual(result["task_groups"], [{"name": "Home", "count": 1, "titles": ["Shared"], "more": 0}])
        self.assertEqual(result["task_active_count"], 2)
        self.assertEqual(result["task_unclassified"]["count"], 1)
        result = self.payload(fixture("real_scale"))
        self.assertEqual(result["task_more_groups"], 57)
        self.assertEqual(result["task_active_count"], 659)
        self.assertEqual(result["task_backlog_count"], 2032)
        self.assertEqual(result["task_unclassified"]["count"], 209)

    def test_native_context_comparator_and_someday_parity(self):
        names = ["home", "Home", "ß", "Z", "[[Work]]"]
        self.assertEqual(sorted(names, key=display._context_key), ["[[Work]]", "Home", "home", "Z", "ß"])
        for tag, inventory in [("someday", True), ("Someday", True), ("#SOMEDAY", True),
                               (" someday", False), ("someday ", False), ("##someday", False), ("someday/later", False)]:
            value = fixture()
            value["tasks"] = [{**task("Idea"), "tags": [tag]}]
            result = self.payload(value)
            self.assertEqual(result["task_backlog_count"], int(inventory), tag)
            self.assertEqual(result["task_active_count"], int(not inventory), tag)
        value["tasks"] = [task("None status", raw="none"), {**task("Finished", raw="done", completed="2026-09-06"), "tags": ["#someday"]}]
        result = self.payload(value)
        self.assertEqual(result["task_backlog_count"], 1)
        self.assertEqual(result["task_done"]["count"], 1)

    def test_cli_cache_failure_preserves_source_time_and_tasks(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            projection, cache = root / "projection.json", root / "cache.json"
            projection.write_text(json.dumps(fixture()))
            command = [sys.executable, str(SCRIPT), "tasks", "--source-vault", "/example/TaskNotes",
                       "--projection", str(projection), "--cache", str(cache)]
            good = subprocess.run(command, capture_output=True, text=True)
            self.assertEqual(good.returncode, 0, good.stderr)
            cached = cache.read_bytes()
            self.assertEqual(cache.stat().st_mode & 0o777, 0o600)
            for bad in ("not JSON", json.dumps({}), json.dumps({**fixture(), "observedAt": None}),
                        json.dumps({**fixture(), "sourceVault": "/wrong"})):
                projection.write_text(bad)
                failed = subprocess.run(command, capture_output=True, text=True)
                self.assertEqual(failed.returncode, 1, failed.stderr)
                value = json.loads(failed.stdout)
                self.assertTrue(value["projection"]["stale"])
                self.assertEqual(value["projection"]["tasks"], fixture()["tasks"])
                self.assertEqual(value["projection"]["observedAt"], NOW.isoformat())
                self.assertEqual(cache.read_bytes(), cached)
            cache.unlink()
            failed = subprocess.run(command, capture_output=True, text=True)
            self.assertEqual(json.loads(failed.stdout)["merge_variables"]["task_state"], "ERROR / NO OBSERVATION")

    def test_live_boundary_invokes_only_snapshot(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            executable = root / "tnote"
            executable.write_text("#!/bin/sh\n[ \"$*\" = 'task snapshot --include-archive' ] || exit 9\n[ \"$TN_VAULT_PATH\" = '/example/TaskNotes' ] || exit 8\ncat <<'JSON'\n" + json.dumps(fixture()) + "\nJSON\n")
            executable.chmod(0o700)
            result = subprocess.run([sys.executable, str(SCRIPT), "tasks", "--source-vault", "/example/TaskNotes",
                                     "--cache", str(root / "cache")], text=True, capture_output=True,
                                    env={**os.environ, "PATH": f"{root}:{os.environ['PATH']}"})
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertFalse(json.loads(result.stdout)["applied"])


if __name__ == "__main__":
    unittest.main()
