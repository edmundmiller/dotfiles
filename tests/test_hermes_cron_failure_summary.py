"""Regression coverage for Hermes cron failure delivery summaries."""

from __future__ import annotations

import ast
import os
import re
import unittest
from pathlib import Path


HERMES_SOURCE = os.environ.get("HERMES_SOURCE")


def _load_failure_summarizer(source: Path):
    scheduler_path = source / "cron" / "scheduler.py"
    tree = ast.parse(scheduler_path.read_text(encoding="utf-8"))
    function = next(
        node
        for node in tree.body
        if isinstance(node, ast.FunctionDef)
        and node.name == "_summarize_cron_failure_for_delivery"
    )
    namespace = {"re": re}
    exec(compile(ast.Module(body=[function], type_ignores=[]), scheduler_path, "exec"), namespace)
    return namespace["_summarize_cron_failure_for_delivery"]


@unittest.skipUnless(HERMES_SOURCE, "set HERMES_SOURCE to the pinned Hermes checkout")
class CronFailureSummaryTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.summarize = staticmethod(_load_failure_summarizer(Path(HERMES_SOURCE)))

    @unittest.expectedFailure
    def test_script_failure_with_429_in_commit_hash_is_not_a_provider_limit(self):
        summary = self.summarize(
            {"id": "job-1", "name": "tnote-schedule", "no_agent": True},
            "Script exited with code 1\nwarning: skipped commit ea6642957",
        )

        self.assertIn("script", summary.lower())
        self.assertNotIn("provider", summary.lower())

    @unittest.expectedFailure
    def test_429_inside_non_provider_identifier_is_not_a_status_code(self):
        summary = self.summarize(
            {"id": "job-1", "name": "tnote-schedule"},
            "git failed while processing commit ea6642957",
        )

        self.assertNotIn("provider", summary.lower())

    def test_http_429_remains_a_provider_rate_limit(self):
        summary = self.summarize(
            {"id": "job-1", "name": "agent-report"},
            "HTTP 429 Too Many Requests",
        )

        self.assertIn("provider rate limit", summary.lower())


if __name__ == "__main__":
    unittest.main()
