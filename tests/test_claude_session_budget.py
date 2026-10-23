import datetime as dt
import importlib.util
import json
import pathlib
import subprocess
import sys
import tempfile
import textwrap
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[1]
HOOK = ROOT / "config/claude/session-budget-hook.py"
FIXTURES = ROOT / "tests/fixtures/claude-session-budget"
MODULE = ROOT / "modules/agents/claude/default.nix"
COMMAND = "$HOME/.claude/hooks/session-budget"


def load_hook():
    # Importing the hook must not leave a __pycache__ behind in config/claude.
    sys.dont_write_bytecode = True
    spec = importlib.util.spec_from_file_location("session_budget_hook", HOOK)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def run_hook(payload, state_dir, env=None):
    environment = {
        "PATH": "/usr/bin:/bin",
        "HOME": str(state_dir),
        "CLAUDE_SESSION_BUDGET_STATE_DIR": str(state_dir),
        "PYTHONDONTWRITEBYTECODE": "1",
    }
    environment.update(env or {})
    result = subprocess.run(
        [sys.executable, str(HOOK)],
        input=payload if isinstance(payload, str) else json.dumps(payload),
        text=True,
        capture_output=True,
        env=environment,
    )
    return result


def hook_output(result):
    """Hook stdout as JSON, after asserting the hook never blocks."""
    assert result.returncode == 0, result.stderr
    if not result.stdout.strip():
        return None
    return json.loads(result.stdout)


def write_transcript(directory, started):
    transcript = pathlib.Path(directory) / "transcript.jsonl"
    entries = [
        {
            "type": "user",
            "timestamp": started.astimezone(dt.timezone.utc).isoformat().replace("+00:00", "Z"),
            "message": {"role": "user", "content": "first prompt"},
        },
        {
            "type": "assistant",
            "timestamp": started.astimezone(dt.timezone.utc).isoformat().replace("+00:00", "Z"),
            "message": {"role": "assistant", "usage": {"input_tokens": 10, "cache_read_input_tokens": 900}},
        },
    ]
    transcript.write_text("\n".join(json.dumps(entry) for entry in entries) + "\n", encoding="utf-8")
    return transcript


class ContextWarningTests(unittest.TestCase):
    def test_under_the_threshold_stays_silent(self):
        with tempfile.TemporaryDirectory() as state:
            result = run_hook(
                {
                    "hook_event_name": "UserPromptSubmit",
                    "session_id": "under",
                    "transcript_path": str(FIXTURES / "under-threshold.jsonl"),
                },
                state,
            )
            self.assertIsNone(hook_output(result))

    def test_crossing_the_threshold_warns_once_per_session(self):
        payload = {
            "hook_event_name": "UserPromptSubmit",
            "session_id": "crossing",
            "transcript_path": str(FIXTURES / "crossing-threshold.jsonl"),
        }
        with tempfile.TemporaryDirectory() as state:
            first = hook_output(run_hook(payload, state))
            self.assertIn("300,000 tokens", first["systemMessage"])
            self.assertIn("/compact", first["systemMessage"])
            self.assertEqual(
                first["hookSpecificOutput"]["hookEventName"],
                "UserPromptSubmit",
            )
            self.assertIn("/compact", first["hookSpecificOutput"]["additionalContext"])
            self.assertNotIn("decision", first)

            self.assertIsNone(hook_output(run_hook(payload, state)))

    def test_each_further_step_warns_again(self):
        with tempfile.TemporaryDirectory() as state:
            session = {"hook_event_name": "Stop", "session_id": "growing"}
            hook_output(
                run_hook(
                    {**session, "transcript_path": str(FIXTURES / "crossing-threshold.jsonl")},
                    state,
                )
            )
            deeper = hook_output(
                run_hook(
                    {**session, "transcript_path": str(FIXTURES / "second-crossing.jsonl")},
                    state,
                )
            )
            self.assertIn("420,000 tokens", deeper["systemMessage"])
            # Stop treats additionalContext as a reason to continue the turn.
            self.assertNotIn("hookSpecificOutput", deeper)

    def test_threshold_and_step_are_configurable(self):
        payload = {
            "hook_event_name": "UserPromptSubmit",
            "session_id": "configured",
            "transcript_path": str(FIXTURES / "under-threshold.jsonl"),
        }
        with tempfile.TemporaryDirectory() as state:
            warned = hook_output(run_hook(payload, state, {"CLAUDE_CONTEXT_WARN_TOKENS": "100000"}))
            self.assertIn("120,000 tokens", warned["systemMessage"])
            self.assertIn("100,000 warning threshold", warned["systemMessage"])

        with tempfile.TemporaryDirectory() as state:
            self.assertIsNone(
                hook_output(run_hook(payload, state, {"CLAUDE_CONTEXT_WARN_TOKENS": "0"}))
            )

    def test_subagent_usage_does_not_count(self):
        tokens = load_hook().context_tokens(FIXTURES / "under-threshold.jsonl")
        self.assertEqual(tokens, 120_000)

    def test_a_huge_transcript_is_read_from_both_ends(self):
        hook = load_hook()
        filler = json.dumps(
            {
                "type": "user",
                "timestamp": "2026-10-20T06:00:00.000Z",
                "message": {"role": "user", "content": "x" * 4000},
            }
        )
        with tempfile.TemporaryDirectory() as directory:
            transcript = pathlib.Path(directory) / "huge.jsonl"
            with transcript.open("w", encoding="utf-8") as handle:
                for _ in range(2000):
                    handle.write(filler + "\n")
                handle.write((FIXTURES / "crossing-threshold.jsonl").read_text(encoding="utf-8"))

            self.assertGreater(transcript.stat().st_size, 8_000_000)
            self.assertEqual(hook.context_tokens(transcript), 300_000)
            self.assertEqual(
                hook.first_entry_date(transcript, dt.timezone.utc),
                dt.date(2026, 10, 20),
            )


class StaleResumeTests(unittest.TestCase):
    def test_same_day_resume_stays_silent(self):
        hook = load_hook()
        zone = hook.session_zone()
        with tempfile.TemporaryDirectory() as state:
            transcript = write_transcript(state, dt.datetime.now(zone))
            result = run_hook(
                {
                    "hook_event_name": "SessionStart",
                    "source": "resume",
                    "session_id": "today",
                    "transcript_path": str(transcript),
                },
                state,
            )
            self.assertIsNone(hook_output(result))

    def test_previous_day_resume_warns_once(self):
        hook = load_hook()
        zone = hook.session_zone()
        # 23:30 yesterday in Chicago lands on today's date in UTC, so reading the
        # raw timestamp would call this a same-day resume and stay silent.
        yesterday = dt.datetime.now(zone).replace(hour=23, minute=30) - dt.timedelta(days=1)
        payload_base = {
            "hook_event_name": "SessionStart",
            "source": "resume",
            "session_id": "yesterday",
        }
        with tempfile.TemporaryDirectory() as state:
            transcript = write_transcript(state, yesterday)
            stamped = dt.datetime.fromisoformat(
                json.loads(transcript.read_text().splitlines()[0])["timestamp"].replace(
                    "Z", "+00:00"
                )
            )
            if str(zone) == "America/Chicago":
                self.assertEqual(stamped.date(), dt.datetime.now(zone).date())

            payload = {**payload_base, "transcript_path": str(transcript)}
            warned = hook_output(run_hook(payload, state))
            self.assertIn(yesterday.date().isoformat(), warned["systemMessage"])
            self.assertIn("America/Chicago", warned["systemMessage"])
            self.assertEqual(
                warned["hookSpecificOutput"]["hookEventName"],
                "SessionStart",
            )

            self.assertIsNone(hook_output(run_hook(payload, state)))

    def test_startup_source_is_never_warned_about(self):
        with tempfile.TemporaryDirectory() as state:
            transcript = write_transcript(state, dt.datetime(2020, 1, 1, tzinfo=dt.timezone.utc))
            result = run_hook(
                {
                    "hook_event_name": "SessionStart",
                    "source": "startup",
                    "session_id": "fresh",
                    "transcript_path": str(transcript),
                },
                state,
            )
            self.assertIsNone(hook_output(result))

    def test_first_entry_date_converts_across_chicago_midnight(self):
        hook = load_hook()
        zone = hook.session_zone()
        started = hook.first_entry_date(FIXTURES / "midnight-boundary.jsonl", zone)
        if str(zone) == "America/Chicago":
            self.assertEqual(started, dt.date(2026, 10, 21))
        else:  # No tzdata: the hook falls back to the machine's own zone.
            self.assertIn(started, (dt.date(2026, 10, 21), dt.date(2026, 10, 22)))


class GenerationWarningTests(unittest.TestCase):
    def payload(self, name, session, event="UserPromptSubmit"):
        return {
            "hook_event_name": event,
            "session_id": session,
            "transcript_path": str(FIXTURES / name),
        }

    def saved_state(self, state_dir, session):
        return json.loads((pathlib.Path(state_dir) / f"{session}.json").read_text(encoding="utf-8"))

    def test_definition_matches_existing_usage_fixtures(self):
        hook = load_hook()
        self.assertEqual(hook.DEFAULT_GEN_WARN_SOFT, 250)
        self.assertEqual(hook.DEFAULT_GEN_WARN_HARD, 300)
        # Same main-thread usage filter as context_tokens: two assistant rows,
        # the sidechain row excluded.
        self.assertEqual(hook.generation_count(FIXTURES / "under-threshold.jsonl", {}), 2)
        self.assertEqual(hook.generation_count(FIXTURES / "malformed.jsonl", {}), 1)

    def test_under_soft_stays_silent(self):
        hook = load_hook()
        transcript = FIXTURES / "under-soft.jsonl"
        self.assertEqual(hook.generation_count(transcript, {}), 249)
        with tempfile.TemporaryDirectory() as state:
            result = run_hook(self.payload("under-soft.jsonl", "under-soft"), state)
            self.assertIsNone(hook_output(result))
            saved = self.saved_state(state, "under-soft")
            self.assertEqual(saved["gen_count"], 249)
            self.assertNotIn("gen_soft_warned", saved)

    def test_crossing_soft_warns_once(self):
        payload = self.payload("crossing-soft.jsonl", "soft")
        with tempfile.TemporaryDirectory() as state:
            first = hook_output(run_hook(payload, state))
            self.assertIn(
                "This session has 250 generations, past the warning at 250.",
                first["systemMessage"],
            )
            self.assertIn("Wrap up, run /compact, or start a fresh session.", first["systemMessage"])
            self.assertNotIn("Hand off", first["systemMessage"])
            self.assertEqual(first["hookSpecificOutput"]["hookEventName"], "UserPromptSubmit")
            self.assertIn("Wrap up", first["hookSpecificOutput"]["additionalContext"])
            self.assertNotIn("decision", first)
            self.assertTrue(self.saved_state(state, "soft")["gen_soft_warned"])

            self.assertIsNone(hook_output(run_hook(payload, state)))

    def test_crossing_hard_warns_once_after_soft(self):
        with tempfile.TemporaryDirectory() as state:
            soft = hook_output(run_hook(self.payload("crossing-soft.jsonl", "marathon"), state))
            self.assertIn("Wrap up", soft["systemMessage"])
            self.assertNotIn("Hand off", soft["systemMessage"])

            hard = hook_output(
                run_hook(self.payload("crossing-hard.jsonl", "marathon", event="Stop"), state)
            )
            self.assertIn(
                "This session has 300 generations, past the higher warning at 300.",
                hard["systemMessage"],
            )
            self.assertIn("Hand off the work or start a fresh session.", hard["systemMessage"])
            self.assertNotIn("Wrap up", hard["systemMessage"])
            self.assertNotIn("hookSpecificOutput", hard)
            self.assertNotIn("decision", hard)
            saved = self.saved_state(state, "marathon")
            self.assertTrue(saved["gen_soft_warned"])
            self.assertTrue(saved["gen_hard_warned"])

            self.assertIsNone(
                hook_output(run_hook(self.payload("crossing-hard.jsonl", "marathon"), state))
            )

    def test_both_thresholds_and_context_warn_together_once(self):
        payload = self.payload("generations-and-context.jsonl", "both")
        with tempfile.TemporaryDirectory() as state:
            warned = hook_output(run_hook(payload, state))
            text = warned["systemMessage"]
            self.assertEqual(warned["hookSpecificOutput"]["additionalContext"], text)
            self.assertIn("Context is about 300,000 tokens", text)
            self.assertIn("This session has 300 generations, past the warning at 250.", text)
            self.assertIn("This session has 300 generations, past the higher warning at 300.", text)
            self.assertNotIn("2,100,005", text)
            self.assertNotIn("decision", warned)
            saved = self.saved_state(state, "both")
            self.assertEqual(saved["context_level"], 1)
            self.assertTrue(saved["gen_soft_warned"])
            self.assertTrue(saved["gen_hard_warned"])

            self.assertIsNone(hook_output(run_hook(payload, state)))

    def test_subagent_turns_do_not_count(self):
        hook = load_hook()
        transcript = FIXTURES / "subagent-turns.jsonl"
        self.assertEqual(hook.generation_count(transcript, {}), 10)
        self.assertEqual(hook.context_tokens(transcript), 3)
        with tempfile.TemporaryDirectory() as state:
            self.assertIsNone(hook_output(run_hook(self.payload("subagent-turns.jsonl", "subs"), state)))
            counted = hook_output(
                run_hook(
                    self.payload("subagent-turns.jsonl", "subs-low"),
                    state,
                    {"CLAUDE_GEN_WARN_SOFT": "10", "CLAUDE_GEN_WARN_HARD": "0"},
                )
            )
            self.assertIn("This session has 10 generations, past the warning at 10.", counted["systemMessage"])
            self.assertNotIn("310", counted["systemMessage"])

    def test_malformed_transcript_fails_open(self):
        hook = load_hook()
        self.assertEqual(hook.generation_count(FIXTURES / "malformed.jsonl", {}), 1)
        with tempfile.TemporaryDirectory() as state:
            result = run_hook(self.payload("malformed.jsonl", "malformed-gen"), state)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(result.stdout.strip(), "")

            directory = pathlib.Path(state) / "not-a-file"
            directory.mkdir()
            unreadable = run_hook(
                {
                    "hook_event_name": "Stop",
                    "session_id": "directory-transcript",
                    "transcript_path": str(directory),
                },
                state,
            )
            self.assertEqual(unreadable.returncode, 0, unreadable.stderr)
            self.assertEqual(unreadable.stdout.strip(), "")
            self.assertIsNone(hook.generation_count(directory, {}))

    def test_session_start_does_not_warn_about_generations(self):
        with tempfile.TemporaryDirectory() as state:
            result = run_hook(
                {
                    "hook_event_name": "SessionStart",
                    "source": "resume",
                    "session_id": "resume-marathon",
                    "transcript_path": str(FIXTURES / "crossing-hard.jsonl"),
                },
                state,
            )
            self.assertIsNone(hook_output(result))
            self.assertFalse((pathlib.Path(state) / "resume-marathon.json").exists())

    def test_thresholds_can_be_lowered_or_silenced(self):
        payload = self.payload("under-threshold.jsonl", "configured-gen")
        with tempfile.TemporaryDirectory() as state:
            warned = hook_output(
                run_hook(payload, state, {"CLAUDE_GEN_WARN_SOFT": "2", "CLAUDE_GEN_WARN_HARD": "2"})
            )
            text = warned["systemMessage"]
            self.assertIn("past the warning at 2.", text)
            self.assertIn("past the higher warning at 2.", text)

        with tempfile.TemporaryDirectory() as state:
            hard_only = hook_output(
                run_hook(
                    self.payload("subagent-turns.jsonl", "hard-only"),
                    state,
                    {"CLAUDE_GEN_WARN_SOFT": "0", "CLAUDE_GEN_WARN_HARD": "10"},
                )
            )
            self.assertNotIn("Wrap up", hard_only["systemMessage"])
            self.assertIn("Hand off", hard_only["systemMessage"])

        with tempfile.TemporaryDirectory() as state:
            self.assertIsNone(
                hook_output(
                    run_hook(
                        self.payload("crossing-hard.jsonl", "silenced"),
                        state,
                        {"CLAUDE_GEN_WARN_SOFT": "0", "CLAUDE_GEN_WARN_HARD": "0"},
                    )
                )
            )

    def test_appended_lines_are_not_double_counted(self):
        usage = {"input_tokens": 1, "cache_read_input_tokens": 1, "cache_creation_input_tokens": 1}
        row = json.dumps({"type": "assistant", "message": {"role": "assistant", "usage": usage}})
        with tempfile.TemporaryDirectory() as state:
            transcript = pathlib.Path(state) / "growing.jsonl"
            transcript.write_text("\n".join([row] * 100) + "\n", encoding="utf-8")
            payload = {
                "hook_event_name": "UserPromptSubmit",
                "session_id": "growing-gen",
                "transcript_path": str(transcript),
            }
            self.assertIsNone(hook_output(run_hook(payload, state)))
            self.assertEqual(self.saved_state(state, "growing-gen")["gen_count"], 100)

            with transcript.open("a", encoding="utf-8") as handle:
                handle.write("\n".join([row] * 50) + "\n")
            self.assertIsNone(hook_output(run_hook(payload, state)))
            self.assertEqual(self.saved_state(state, "growing-gen")["gen_count"], 150)

    def test_rewritten_transcript_is_recounted(self):
        hook = load_hook()

        def write_gens(path, count, marker):
            usage = {"input_tokens": 1, "cache_read_input_tokens": 1, "cache_creation_input_tokens": 1}
            lines = [json.dumps({"type": "summary", "summary": marker * 80})]
            lines.extend(
                json.dumps({"type": "assistant", "message": {"role": "assistant", "usage": usage}})
                for _ in range(count)
            )
            path.write_text("\n".join(lines) + "\n", encoding="utf-8")

        with tempfile.TemporaryDirectory() as state:
            transcript = pathlib.Path(state) / "replaced.jsonl"
            write_gens(transcript, 5, "a")
            cursor = {}
            self.assertEqual(hook.generation_count(transcript, cursor), 5)
            write_gens(transcript, 8, "b")
            self.assertEqual(hook.generation_count(transcript, cursor), 8)

    def test_unwritable_state_still_warns(self):
        payload = self.payload("crossing-soft.jsonl", "no-state-gen")
        with tempfile.TemporaryDirectory() as directory:
            blocked = pathlib.Path(directory) / "state"
            blocked.write_text("not a directory\n", encoding="utf-8")
            warned = hook_output(run_hook(payload, blocked))
            self.assertIn("250 generations", warned["systemMessage"])


class FailOpenTests(unittest.TestCase):
    def test_malformed_inputs_exit_zero_without_output(self):
        cases = [
            "not json",
            "",
            json.dumps([1, 2, 3]),
            json.dumps({"hook_event_name": "Stop", "session_id": "missing-transcript"}),
            json.dumps(
                {
                    "hook_event_name": "Stop",
                    "session_id": "unreadable",
                    "transcript_path": "/nonexistent/transcript.jsonl",
                }
            ),
            json.dumps(
                {
                    "hook_event_name": "Stop",
                    "session_id": "malformed-transcript",
                    "transcript_path": str(FIXTURES / "malformed.jsonl"),
                }
            ),
        ]
        with tempfile.TemporaryDirectory() as state:
            for case in cases:
                with self.subTest(case=case[:40]):
                    result = run_hook(case, state)
                    self.assertEqual(result.returncode, 0, result.stderr)
                    self.assertEqual(result.stdout.strip(), "")

    def test_unwritable_state_still_warns(self):
        payload = {
            "hook_event_name": "UserPromptSubmit",
            "session_id": "no-state",
            "transcript_path": str(FIXTURES / "crossing-threshold.jsonl"),
        }
        with tempfile.TemporaryDirectory() as directory:
            blocked = pathlib.Path(directory) / "state"
            blocked.write_text("not a directory\n", encoding="utf-8")
            warned = hook_output(run_hook(payload, blocked))
            self.assertIn("300,000 tokens", warned["systemMessage"])


class WiringTests(unittest.TestCase):
    def activation_script(self):
        module = MODULE.read_text(encoding="utf-8")
        block = module.split("home.activation.claude-session-budget-hooks", 1)[1]
        return textwrap.dedent(block.split("<<'PY'\n", 1)[1].split("\n            PY", 1)[0])

    def test_module_installs_the_hook_next_to_the_status_line(self):
        module = MODULE.read_text(encoding="utf-8")
        self.assertIn('".claude/hooks/session-budget".source', module)
        self.assertIn("session-budget-hook.py", module)
        self.assertIn('sessionBudgetCommand = "$HOME/.claude/hooks/session-budget"', module)

    def test_activation_adds_hooks_without_touching_plugins_or_other_hooks(self):
        herdr = {"hooks": [{"type": "command", "command": "herdr hook"}]}
        settings = {
            "enabledPlugins": {
                "pstack@cursor-plugins": True,
                "agento11y-claude-code@agento11y": True,
            },
            "hooks": {"SessionStart": [herdr], "Stop": [herdr]},
        }
        with tempfile.TemporaryDirectory() as directory:
            target = pathlib.Path(directory) / "settings.json"
            target.write_text(json.dumps(settings), encoding="utf-8")
            for _ in range(2):
                subprocess.run(
                    [sys.executable, "-c", self.activation_script(), str(target), COMMAND],
                    check=True,
                )

            written = json.loads(target.read_text(encoding="utf-8"))
            self.assertEqual(written["enabledPlugins"], settings["enabledPlugins"])
            entry = {"hooks": [{"type": "command", "command": COMMAND}]}
            self.assertEqual(
                written["hooks"],
                {
                    "SessionStart": [herdr, {**entry, "matcher": "resume"}],
                    "Stop": [herdr, entry],
                    "UserPromptSubmit": [entry],
                },
            )

    def test_activation_tolerates_a_missing_or_broken_settings_file(self):
        with tempfile.TemporaryDirectory() as directory:
            target = pathlib.Path(directory) / "settings.json"
            subprocess.run(
                [sys.executable, "-c", self.activation_script(), str(target), COMMAND],
                check=True,
            )
            self.assertEqual(set(json.loads(target.read_text())["hooks"]), {
                "SessionStart",
                "Stop",
                "UserPromptSubmit",
            })

            for broken in ("{not json", json.dumps({"hooks": []})):
                target.write_text(broken, encoding="utf-8")
                subprocess.run(
                    [sys.executable, "-c", self.activation_script(), str(target), COMMAND],
                    check=True,
                )
                self.assertIn("UserPromptSubmit", json.loads(target.read_text())["hooks"])


if __name__ == "__main__":
    unittest.main()
