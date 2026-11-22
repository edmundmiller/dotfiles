#!/usr/bin/env -S uv run --script
# /// script
# dependencies = []
# [tool.uv]
# exclude-newer = "2026-11-21T00:00:00Z"
# ///
"""Test a compiled helper. --gui also edits an isolated native/WebKit fixture.

Usage: python3 native/test_focused_text.py /path/to/focused-text [--gui]
"""

import json
from pathlib import Path
import plistlib
import selectors
import subprocess
import sys
import tempfile
import time
import unittest


HELPER_PATH = sys.argv.pop(1) if len(sys.argv) > 1 else None
RUN_GUI_TESTS = "--gui" in sys.argv
if RUN_GUI_TESTS:
    sys.argv.remove("--gui")


class FocusedTextProtocolTests(unittest.TestCase):
    def setUp(self):
        if HELPER_PATH is None:
            self.fail("Pass the compiled helper path as the first argument")
        self.helper = subprocess.Popen(
            [HELPER_PATH],
            stdin=subprocess.PIPE,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
        )
        self.addCleanup(self.close_helper)

    def close_helper(self):
        if self.helper.stdin and not self.helper.stdin.closed:
            self.helper.stdin.close()
        try:
            self.helper.wait(timeout=5)
        except subprocess.TimeoutExpired:
            self.helper.kill()
            self.helper.wait()
            self.fail("Helper did not exit after stdin EOF")
        finally:
            self.helper.stdout.close()
            self.helper.stderr.close()

    def request(self, request, process=None):
        process = process or self.helper
        process.stdin.write(request.encode("utf-8") + b"\n")
        process.stdin.flush()
        with selectors.DefaultSelector() as selector:
            selector.register(process.stdout, selectors.EVENT_READ)
            self.assertTrue(
                selector.select(timeout=5), "Helper did not reply before EOF"
            )
        line = process.stdout.readline()
        self.assertTrue(
            line.endswith(b"\n"), "Reply must be one newline-terminated JSON object"
        )
        reply = json.loads(line)
        self.assertIsInstance(reply, dict)
        return reply

    def test_persistent_status_clear_and_empty_undo(self):
        for _ in range(3):
            status = self.request('{"op":"status"}')
            self.assertEqual(set(status), {"trusted", "apple_autocorrect"})
            self.assertIs(type(status["trusted"]), bool)
            self.assertIs(type(status["apple_autocorrect"]), bool)
            self.assertEqual(self.request('{"op":"clear"}'), {})
            self.assertEqual(
                self.request('{"op":"undo"}'), {"applied": False, "reason": "no_undo"}
            )

    def test_apple_autocorrect_status_on_and_off_without_changing_mac_settings(self):
        # Foundation's argument domain changes only this child's preference.
        for argument, expected in [("YES", True), ("NO", False)]:
            with self.subTest(autocorrect=argument):
                result = subprocess.run(
                    [HELPER_PATH, "-NSAutomaticSpellingCorrectionEnabled", argument],
                    input=b'{"op":"status"}\n',
                    capture_output=True,
                    check=True,
                    timeout=5,
                )
                self.assertIs(json.loads(result.stdout)["apple_autocorrect"], expected)
                self.assertEqual(result.stderr, b"")

    def test_invalid_lines_do_not_break_next_request(self):
        for invalid in [
            "",
            "not JSON",
            "[]",
            "null",
            "{}",
            '{"op":4}',
            '{"op":"status","token":-1}',
        ]:
            with self.subTest(request=invalid):
                self.assertEqual(
                    self.request(invalid),
                    {"applied": False, "reason": "invalid_request"},
                )
        self.assertEqual(
            self.request('{"op":"unknown"}'),
            {"applied": False, "reason": "unsupported_operation"},
        )
        self.assertEqual(
            set(self.request('{"op":"status"}')), {"trusted", "apple_autocorrect"}
        )

    def test_replace_without_snapshot_is_rejected_including_full_uint64(self):
        for token in [1, 18446744073709551615]:
            request = {
                "op": "replace",
                "token": token,
                "text": "😀 teh ",
                "caret": 7,
                "from": 3,
                "to": 6,
                "original": "teh",
                "replacement": "the",
            }
            self.assertEqual(
                self.request(json.dumps(request)),
                {"applied": False, "reason": "stale_token"},
            )

    def test_eof_exits_without_extra_stdout_or_stderr(self):
        self.assertEqual(self.request('{"op":"clear"}'), {})
        self.helper.stdin.close()
        self.assertEqual(self.helper.wait(timeout=5), 0)
        self.assertEqual(self.helper.stdout.read(), b"")
        self.assertEqual(self.helper.stderr.read(), b"")

    @unittest.skipUnless(
        RUN_GUI_TESTS, "Pass --gui to activate and edit a disposable fixture"
    )
    def test_native_and_web_inputs_commit_edits_and_guard_undo(self):
        self.assertTrue(
            self.request('{"op":"status"}')["trusted"],
            "GUI tests need existing Accessibility access",
        )
        directory = tempfile.TemporaryDirectory(prefix="tinytype-input-test-")
        self.addCleanup(directory.cleanup)
        contents = Path(directory.name) / "InputFixture.app" / "Contents"
        binary = contents / "MacOS" / "fixture"
        binary.parent.mkdir(parents=True)
        (contents / "Info.plist").write_bytes(
            plistlib.dumps(
                {
                    "CFBundleIdentifier": "dev.edmundmiller.tinytype-fixture",
                    "CFBundleExecutable": "fixture",
                }
            )
        )
        subprocess.run(
            [
                "/usr/bin/xcrun",
                "swiftc",
                str(Path(__file__).with_name("InputFixture.swift")),
                "-o",
                str(binary),
            ],
            check=True,
            timeout=60,
        )
        subprocess.run(
            ["/usr/bin/codesign", "--force", "--sign", "-", str(contents.parent)],
            check=True,
            timeout=15,
        )
        fixture = subprocess.Popen(
            [str(binary)],
            stdin=subprocess.PIPE,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
        )
        self.addCleanup(lambda: fixture.communicate(timeout=5))

        def fixture_request(**request):
            return self.request(json.dumps(request), fixture)

        def javascript(script):
            result = fixture_request(op="js", script=script)
            self.assertEqual(result["error"], "")
            return result["value"]

        def feedback_windows():
            result = fixture_request(op="feedback", pid=self.helper.pid)
            self.assertEqual(
                result["frontmost"],
                fixture.pid,
                "Fixture lost focus during feedback check",
            )
            return result["windows"]

        def wait_for_feedback(count):
            deadline = time.monotonic() + 1
            while len(feedback_windows()) != count:
                self.assertLess(
                    time.monotonic(), deadline, "Feedback visibility did not settle"
                )
                time.sleep(0.02)

        fixture_request(op="native", text="😀 goood later", caret=9)
        # Allow activation and the fixture's initial WebKit navigation to settle.
        time.sleep(0.5)
        deadline = time.monotonic() + 5
        while javascript("document.readyState") != "complete":
            self.assertLess(
                time.monotonic(), deadline, "Fixture navigation did not complete"
            )
            time.sleep(0.05)

        for field in ["native", "area", "single", "rich"]:
            with self.subTest(field=field):
                if field == "native":
                    fixture_request(op="native", text="😀 goood later", caret=9)
                else:
                    javascript(f"""(() => {{
                        let e = document.getElementById('{field}');
                        if (e.isContentEditable) {{
                            e.textContent = '😀 goood later'; e.focus();
                            let r = document.createRange(); r.setStart(e.firstChild, 9); r.collapse(true);
                            getSelection().removeAllRanges(); getSelection().addRange(r);
                        }} else {{ e.value = '😀 goood later'; e.focus(); e.setSelectionRange(9, 9); }}
                        inputEvents = 0;
                    }})()""")
                    time.sleep(0.3)  # AX focus notifications trail DOM focus.
                reply = self.request('{"op":"snapshot"}')
                snapshot = reply["snapshot"]
                self.assertIsNotNone(snapshot, reply)
                self.assertEqual(
                    snapshot["bundle"], "dev.edmundmiller.tinytype-fixture"
                )
                self.assertEqual(snapshot["text"], "😀 goood later")
                edit = dict(
                    snapshot, op="replace", to=8, original="goood", replacement="good"
                )
                edit["from"] = 3
                self.assertEqual(self.request(json.dumps(edit)), {"applied": True})
                wait_for_feedback(1)
                if field == "native":
                    self.assertEqual(
                        fixture_request(op="value"),
                        {"text": "😀 good later", "caret": 8},
                    )
                    time.sleep(2)
                    wait_for_feedback(
                        1
                    )  # Remains readable beyond the old 1.5-second timeout.
                    time.sleep(2.3)
                    wait_for_feedback(0)
                else:
                    self.assertEqual(
                        javascript(
                            f"(() => {{ let e = document.getElementById('{field}'); return [e.value ?? e.textContent, e.selectionStart ?? getSelection().anchorOffset, inputEvents]; }})()"
                        ),
                        ["😀 good later", 8, 1],
                    )
                self.assertEqual(
                    self.request('{"op":"undo"}'),
                    {"applied": True, "original": "goood"},
                )
                wait_for_feedback(1)
                if field == "native":
                    self.assertEqual(
                        fixture_request(op="value"),
                        {"text": "😀 goood later", "caret": 9},
                    )
                    self.assertEqual(self.request('{"op":"clear"}'), {})
                    wait_for_feedback(0)
                else:
                    self.assertEqual(
                        javascript(
                            f"(() => {{ let e = document.getElementById('{field}'); return [e.value ?? e.textContent, e.selectionStart ?? getSelection().anchorOffset, inputEvents]; }})()"
                        ),
                        ["😀 goood later", 9, 2],
                    )
                self.assertEqual(
                    self.request('{"op":"undo"}'),
                    {"applied": False, "reason": "no_undo"},
                )

        # The unchanged tail can contain words and surrogate pairs. Both the
        # original span and its replacement must fit the single-event limit.
        for before, caret, replacement, after, after_caret, applied in [
            (
                "😀 goood a 🦀 word later",
                19,
                "good",
                "😀 good a 🦀 word later",
                18,
                True,
            ),
            (
                "😀 goood 1234567890123 later",
                23,
                "good",
                "😀 good 1234567890123 later",
                22,
                True,
            ),
            (
                "😀 goood 12345678901234 later",
                24,
                "good",
                "😀 goood 12345678901234 later",
                24,
                False,
            ),
            (
                "😀 goood 1234567890123 later",
                23,
                "gooood",
                "😀 goood 1234567890123 later",
                23,
                False,
            ),
        ]:
            with self.subTest(caret=caret, replacement=replacement):
                javascript(f"""(() => {{
                    let e = document.getElementById('area');
                    e.value = {json.dumps(before)}; e.focus(); e.setSelectionRange({caret}, {caret});
                }})()""")
                time.sleep(0.3)
                reply = self.request('{"op":"snapshot"}')
                snapshot = reply["snapshot"]
                self.assertIsNotNone(snapshot, reply)
                self.assertEqual(
                    snapshot["bundle"], "dev.edmundmiller.tinytype-fixture"
                )
                self.assertEqual(snapshot["text"], before)
                self.assertEqual(snapshot["caret"], caret)
                edit = dict(
                    snapshot,
                    op="replace",
                    to=8,
                    original="goood",
                    replacement=replacement,
                )
                edit["from"] = 3
                reply = self.request(json.dumps(edit))
                self.assertEqual(reply["applied"], applied, reply)
                self.assertEqual(
                    javascript(
                        "(() => { let e = document.getElementById('area'); return [e.value, e.selectionStart]; })()"
                    ),
                    [after, after_caret],
                )

        # Resume input as soon as the correction lands, before the helper can
        # verify it. The next character belongs at the user's original caret,
        # not between the corrected word and its trailing space.
        javascript("""(() => {
            let e = document.getElementById('area');
            e.value = '😀 goood later'; e.focus(); e.setSelectionRange(9, 9);
            e.addEventListener('input', () => {
                e.setRangeText('x', e.selectionStart, e.selectionEnd, 'end');
            }, {once: true});
        })()""")
        time.sleep(0.3)
        reply = self.request('{"op":"snapshot"}')
        snapshot = reply["snapshot"]
        self.assertIsNotNone(snapshot, reply)
        self.assertEqual(snapshot["bundle"], "dev.edmundmiller.tinytype-fixture")
        self.assertEqual(snapshot["text"], "😀 goood later")
        self.assertEqual(snapshot["caret"], 9)
        edit = dict(snapshot, op="replace", to=8, original="goood", replacement="good")
        edit["from"] = 3
        reply = self.request(json.dumps(edit))
        self.assertEqual(
            javascript(
                "(() => { let e = document.getElementById('area'); return [e.value, e.selectionStart]; })()"
            ),
            ["😀 good xlater", 9],
            "Continued typing must not use the correction's temporary caret",
        )
        self.assertEqual(
            reply, {"applied": False, "reason": "edit_failed_text_may_have_changed"}
        )

        fixture_request(op="native", text="selected text", caret=0, length=8)
        time.sleep(0.3)
        wait_for_feedback(0)
        self.assertEqual(
            self.request('{"op":"snapshot"}')["reason"], "selection_not_collapsed"
        )
        for field in ["readonly", "password"]:
            javascript(f"document.getElementById('{field}').focus()")
            time.sleep(0.3)
            self.assertIsNone(self.request('{"op":"snapshot"}')["snapshot"])


if __name__ == "__main__":
    unittest.main()
