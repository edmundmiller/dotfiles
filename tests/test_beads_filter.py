"""Read-only audit, disclosure boundaries and ranked Jev output."""

import contextlib
import io
import json
import os
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

from scripts import beads_filter as cli


class BeadsFilterTests(unittest.TestCase):
    def setUp(self):
        directory = tempfile.TemporaryDirectory()
        self.addCleanup(directory.cleanup)
        self.path = Path(directory.name) / "issues.jsonl"
        self.issues = [
            {
                "id": "a",
                "title": "Same task",
                "status": "open",
                "owner": "private-owner",
                "notes": "private-note",
            },
            {
                "id": "b",
                "title": " same TASK ",
                "status": "closed",
                "close_reason": "Duplicate of a",
            },
            {"id": "c", "title": "Same task", "status": "tombstone"},
            {
                "id": "d",
                "title": "Fix an error",
                "status": "in_progress",
                "description": "Concrete reproduction",
            },
        ]
        self.write()

    def write(self):
        self.path.write_text("\n".join(json.dumps(x) for x in self.issues) + "\n")

    def invoke(self, *args):
        before = self.path.read_bytes()
        output, error = io.StringIO(), io.StringIO()
        with contextlib.redirect_stdout(output), contextlib.redirect_stderr(error):
            code = cli.main(["--file", str(self.path), *args])
        self.assertEqual(self.path.read_bytes(), before)
        return code, output.getvalue(), error.getvalue()

    def test_offline_audit_preserves_canonical_open_issue_and_ignores_tombstone(self):
        with patch.object(
            cli.urllib.request,
            "urlopen",
            side_effect=AssertionError("network forbidden"),
        ):
            code, output, _ = self.invoke()
        self.assertEqual(code, 0)
        result = json.loads(output)
        group = result["same_title_candidates"][0]
        self.assertEqual([x["id"] for x in group], ["a", "b"])
        self.assertEqual(group[1]["close_reason"], "Duplicate of a")
        self.assertEqual([x["id"] for x in result["missing_details"]], ["a"])
        self.assertTrue(result["advisory_only"])

    def test_preview_discloses_only_allowed_fields_and_all_active_ids(self):
        with patch.object(
            cli.urllib.request,
            "urlopen",
            side_effect=AssertionError("network forbidden"),
        ):
            code, output, _ = self.invoke("--query", "needs clarification", "--plan")
        self.assertEqual(code, 0)
        result = json.loads(output)
        self.assertEqual(result["evaluated"], 2)
        self.assertEqual(
            [x["id"] for x in result["requests"][0]["state"]["issues"]], ["a", "d"]
        )
        self.assertNotIn("private-owner", output)
        self.assertNotIn("private-note", output)
        code, output, _ = self.invoke(
            "--query", "needs clarification", "--plan", "--id", "b"
        )
        self.assertEqual(code, 0)
        self.assertEqual(
            [x["id"] for x in json.loads(output)["requests"][0]["state"]["issues"]],
            ["b"],
        )

    def test_ranks_across_batches_before_limiting_and_reports_usage(self):
        self.issues = [
            {"id": f"i{i:02}", "title": f"Task {i}", "status": "open"}
            for i in range(11)
        ]
        self.write()

        # The winner is in the second batch; slicing before evaluation would miss it.
        def response(request, **_):
            payload = json.loads(request.data)
            return io.BytesIO(
                json.dumps(
                    {
                        "model": "jev-test",
                        "usage": {"input_tokens": 100, "output_tokens": 10},
                        "answers": {
                            key: {"type": "noul", "noul": 0.95 if key == "i10" else 0.1}
                            for key in payload["questions"]
                        },
                    }
                ).encode()
            )

        with patch.dict(os.environ, {"TYPESAFE_API_KEY": "test-only"}), patch.object(
            cli.urllib.request, "urlopen", side_effect=response
        ):
            code, output, _ = self.invoke(
                "--query", "needs clarification", "--jev", "--limit", "1"
            )
        self.assertEqual(code, 0)
        result = json.loads(output)
        self.assertEqual(result["evaluated"], 11)
        self.assertEqual(
            result["matches"],
            [{"id": "i10", "title": "Task 10", "status": "open", "probability": 0.95}],
        )
        self.assertEqual(result["usage"], {"input_tokens": 200, "output_tokens": 20})

    def test_invalid_or_missing_answers_fail_without_output(self):
        for probability in (-0.1, 1.1, True, float("nan"), "0.8", None):
            with self.subTest(probability=probability):
                answers = (
                    {"a": {"type": "noul", "noul": probability}}
                    if probability is not None
                    else {}
                )
                body = {
                    "model": "jev-test",
                    "answers": answers,
                    "usage": {"input_tokens": 1, "output_tokens": 1},
                }
                with patch.dict(
                    os.environ, {"TYPESAFE_API_KEY": "test-only"}
                ), patch.object(
                    cli.urllib.request,
                    "urlopen",
                    return_value=io.BytesIO(json.dumps(body).encode()),
                ):
                    code, output, error = self.invoke(
                        "--query", "needs clarification", "--jev", "--id", "a"
                    )
                self.assertEqual(code, 1)
                self.assertEqual(output, "")
                self.assertIn("Invalid TypeSafe response", error)

    def test_unknown_id_missing_key_and_malformed_source_fail_closed(self):
        with patch.object(
            cli.urllib.request,
            "urlopen",
            side_effect=AssertionError("network forbidden"),
        ), patch.dict(os.environ, {}, clear=True):
            for args, expected in [
                (
                    ("--query", "cleanup", "--plan", "--id", "missing"),
                    "Unknown issue IDs",
                ),
                (("--query", "cleanup", "--jev"), "Set TYPESAFE_API_KEY"),
            ]:
                code, output, error = self.invoke(*args)
                self.assertEqual(code, 1)
                self.assertEqual(output, "")
                self.assertIn(expected, error)
            self.path.write_text('{"id": "broken"}\n')
            code, output, error = self.invoke()
            self.assertEqual(code, 1)
            self.assertEqual(output, "")
            self.assertIn("issues.jsonl:1", error)

    def test_query_requires_explicit_network_or_preview_mode(self):
        for args in (
            ("--query", "cleanup"),
            ("--jev",),
            ("--query", " "),
            ("--limit", "0"),
        ):
            with self.subTest(args=args), contextlib.redirect_stderr(
                io.StringIO()
            ), self.assertRaises(SystemExit) as error:
                self.invoke(*args)
            self.assertEqual(error.exception.code, 2)


if __name__ == "__main__":
    unittest.main()
