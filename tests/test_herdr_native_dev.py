"""Exercise the installed CLI boundary without contacting a live Herdr app."""

import json
import os
from pathlib import Path
import subprocess
import sys

import pytest


HELPER = Path(__file__).resolve().parents[1] / "config/herdr/native/herdr-dev.py"


@pytest.fixture
def native_cli(tmp_path):
    repo = tmp_path / "repo with 'quotes; $(false)"
    repo.mkdir()
    subprocess.run(["git", "init", "-q", str(repo)], check=True)
    subprocess.run(
        ["git", "-c", "user.name=Test", "-c", "user.email=test@example.invalid",
         "-C", str(repo), "commit", "-qm", "initial", "--allow-empty"], check=True,
    )
    bindir = tmp_path / "bin"
    bindir.mkdir()
    log = tmp_path / "app.jsonl"
    fake_app = bindir / "herdr-app"
    fake_app.write_text(
        f"#!{sys.executable}\n" + '''import json, os, sys
from pathlib import Path
args = sys.argv[1:]
with open(os.environ["APP_LOG"], "a") as log:
    log.write(json.dumps(args) + "\\n")
if os.environ.get("REQUIRE_SEED"):
    assert Path(os.environ["REQUIRE_SEED"]).read_text() == "seeded"
if args == ["status"]:
    reply = {"space": "space-A", "tab": "agent-A", "focused_pane": "pane-A"}
    if os.environ.get("NO_PANE"):
        reply["focused_pane"] = None
elif args == ["ls"]:
    reply = {"spaces": [{"id": "space-A", "machine": os.environ.get("REMOTE"),
        "tabs": [{"id": "agent-A", "terminals": [{"pane": "pane-A"}]}]}]}
elif args[:2] == ["do", "space.new"]:
    reply = {"space": "space-created", "tab": "agent-created", "terminal": "t10"}
elif args[:2] == ["do", "tab.new"]:
    reply = {"tab": "hunk-created", "terminal": "t11"}
elif args[:2] == ["do", "pane.split"]:
    reply = {"pane": "pane-hunk", "terminal": "t12"}
else:
    raise SystemExit("Unexpected app command: " + repr(args))
if len(args) > 1 and args[1] == os.environ.get("FAIL_COMMAND"):
    if os.environ.get("BAD_JSON"):
        print("truncated reply")
        raise SystemExit(0)
    if os.environ.get("MISSING_ID"):
        reply.pop("terminal", None)
    else:
        print(json.dumps({"error": "layout unavailable"}))
        raise SystemExit(int(os.environ.get("FAIL_CODE", "1")))
print(json.dumps(reply))
'''
    )
    fake_app.chmod(0o755)
    env = {**os.environ, "PATH": str(bindir) + os.pathsep + os.environ["PATH"], "APP_LOG": str(log)}

    def invoke(*args, **extra_env):
        result = subprocess.run(
            [sys.executable, str(HELPER), *map(str, args)], cwd=repo,
            env={**env, **extra_env}, capture_output=True, text=True,
        )
        calls = [json.loads(line) for line in log.read_text().splitlines()] if log.exists() else []
        return result, calls

    return repo, invoke


def expected_hunk_argv(repo, *args):
    # Independent contract from workspace-manager.yml, with positional parameters.
    return ["sh", "-c",
            'cd "$1" || exit; shift; if command -v hunk >/dev/null 2>&1; '
            'then exec hunk diff --no-transparent-bg "$@"; '
            'else exec bunx hunkdiff diff --no-transparent-bg "$@"; fi',
            "herdr-dev-hunk", str(repo), *args]


@pytest.mark.parametrize("agent", [None, "pi", "omp", "claude", "codex", "opencode"])
def test_open_creates_agent_then_explicit_hunk_tab(native_cli, agent):
    repo, invoke = native_cli
    result, calls = invoke("open", repo, *(["--agent", agent] if agent else []))
    assert result.returncode == 0, result.stderr
    selected = agent or "omp"
    assert [call[:2] for call in calls] == [["do", "space.new"], ["do", "tab.new"]]
    assert json.loads(calls[0][2]) == {"folder": str(repo), "tab": selected, "argv": [selected]}
    assert json.loads(calls[1][2]) == {
        "space": "space-created", "name": "hunk", "folder": str(repo),
        "argv": expected_hunk_argv(repo),
    }
    assert json.loads(result.stdout) == {
        "agent": {"space": "space-created", "tab": "agent-created", "terminal": "t10"},
        "hunk": {"tab": "hunk-created", "terminal": "t11"},
    }


@pytest.mark.parametrize("invalid", ["missing", "file", "nonrepo"])
def test_invalid_folder_never_contacts_app(native_cli, tmp_path, invalid):
    _, invoke = native_cli
    target = tmp_path / invalid
    if invalid == "file":
        target.write_text("not a directory")
    elif invalid == "nonrepo":
        target.mkdir()
    result, calls = invoke("open", target)
    assert result.returncode == 1
    assert calls == []
    assert result.stderr.startswith("herdr-dev:")


@pytest.mark.parametrize("fails", [False, True])
def test_qmd_hook_finishes_before_any_app_call(native_cli, fails):
    repo, invoke = native_cli
    scripts = repo / "scripts"
    scripts.mkdir()
    seed = scripts / "qmd-seed-worktree.sh"
    marker = repo / "seed-result"
    seed.write_text("#!/bin/sh\nprintf seeded > seed-result\n" + ("exit 9\n" if fails else ""))
    seed.chmod(0o755)
    result, calls = invoke("open", repo, REQUIRE_SEED=str(marker))
    assert marker.read_text() == "seeded"
    if fails:
        assert result.returncode == 1
        assert calls == []
        assert "exited 9" in result.stderr
    else:
        assert result.returncode == 0, result.stderr
        assert len(calls) == 2


@pytest.mark.parametrize("failure", [{}, {"FAIL_CODE": "0"}, {"BAD_JSON": "1"}, {"MISSING_ID": "1"}])
def test_partial_open_reports_created_ids_without_cleanup(native_cli, failure):
    repo, invoke = native_cli
    result, calls = invoke("open", repo, FAIL_COMMAND="tab.new", **failure)
    assert result.returncode == 1
    assert "space-created" in result.stderr
    assert "agent-created" in result.stderr
    assert "nothing was closed or removed" in result.stderr
    assert [call[:2] for call in calls] == [["do", "space.new"], ["do", "tab.new"]]


@pytest.mark.parametrize("options,diff_args", [([], []), (["--staged"], ["--staged"]), (["--branch", "HEAD"], ["HEAD"])])
def test_hunk_targets_captured_pane_with_correct_diff_mode(native_cli, options, diff_args):
    repo, invoke = native_cli
    result, calls = invoke("hunk", *options)
    assert result.returncode == 0, result.stderr
    assert calls[:2] == [["status"], ["ls"]]
    assert calls[2][:2] == ["do", "pane.split"]
    assert json.loads(calls[2][2]) == {
        "pane": "pane-A", "direction": "right", "argv": expected_hunk_argv(repo, *diff_args),
    }
    assert json.loads(result.stdout) == {"pane": "pane-hunk", "terminal": "t12"}


@pytest.mark.parametrize("env", [{"NO_PANE": "1"}, {"REMOTE": "server"}])
def test_hunk_rejects_unsupported_context_without_mutation(native_cli, env):
    _, invoke = native_cli
    result, calls = invoke("hunk", **env)
    assert result.returncode == 1
    assert all(call[0] != "do" for call in calls)


@pytest.mark.parametrize("options", [["--branch", "not-a-real-ref"], ["--branch=--staged"], ["--staged", "--branch", "HEAD"]])
def test_hunk_invalid_base_or_conflicting_flags_never_contacts_app(native_cli, options):
    _, invoke = native_cli
    result, calls = invoke("hunk", *options)
    assert result.returncode != 0
    assert calls == []


def test_hunk_explicit_pane_does_not_follow_changed_focus(native_cli):
    _, invoke = native_cli
    result, calls = invoke("hunk", "--pane", "pane-A", NO_PANE="1")
    assert result.returncode == 0, result.stderr
    assert calls[0] == ["ls"]
    assert [call[:2] for call in calls[1:]] == [["do", "pane.split"]]
    assert json.loads(calls[-1][2])["pane"] == "pane-A"


@pytest.mark.parametrize("pane,extra", [("gone-pane", {}), ("pane-A", {"REMOTE": "server"})])
def test_hunk_explicit_pane_must_still_be_a_live_local_terminal(native_cli, pane, extra):
    _, invoke = native_cli
    result, calls = invoke("hunk", "--pane", pane, **extra)
    assert result.returncode == 1
    assert "remote/composition panes are unsupported" in result.stderr
    assert calls == [["ls"]]


def test_hunk_partial_failure_is_not_cleaned_up(native_cli):
    _, invoke = native_cli
    result, calls = invoke("hunk", FAIL_COMMAND="pane.split", MISSING_ID="1")
    assert result.returncode == 1
    assert "pane-hunk" in result.stderr
    assert "nothing was closed or removed" in result.stderr
    assert len(calls) == 3


@pytest.mark.parametrize("installed", [True, False])
def test_hunk_shell_fallback_executes_literal_argv_in_repository(native_cli, tmp_path, installed):
    repo, invoke = native_cli
    result, calls = invoke("open", repo)
    assert result.returncode == 0, result.stderr
    argv = json.loads(calls[1][2])["argv"]
    bindir = tmp_path / "review-bin"
    bindir.mkdir()
    output = tmp_path / "review.json"
    recorder = (
        f"#!{sys.executable}\nimport json, os, sys\n"
        "from pathlib import Path\n"
        "Path(os.environ['REVIEW_OUTPUT']).write_text(json.dumps([os.getcwd(), sys.argv[1:]]))\n"
    )
    executable = bindir / ("hunk" if installed else "bunx")
    executable.write_text(recorder)
    executable.chmod(0o755)
    # No real Hunk/bunx is reachable; the shell must pass these as data.
    literal_ref = "base; $(touch MUST_NOT_EXIST)"
    review = subprocess.run(
        ["/bin/sh", *argv[1:], literal_ref], cwd=tmp_path,
        env={**os.environ, "PATH": str(bindir), "REVIEW_OUTPUT": str(output)},
        capture_output=True, text=True,
    )
    assert review.returncode == 0, review.stderr
    expected_args = ["diff", "--no-transparent-bg", literal_ref]
    if not installed:
        expected_args.insert(0, "hunkdiff")
    assert json.loads(output.read_text()) == [str(repo), expected_args]
    assert not (repo / "MUST_NOT_EXIST").exists()


def test_failed_first_request_stops_without_creating_hunk(native_cli):
    repo, invoke = native_cli
    result, calls = invoke("open", repo, FAIL_COMMAND="space.new")
    assert result.returncode == 1
    assert "layout unavailable" in result.stderr
    assert "UI may have changed" in result.stderr
    assert [call[:2] for call in calls] == [["do", "space.new"]]


def test_jj_lifecycle_is_explicitly_unsupported(native_cli):
    _, invoke = native_cli
    result, calls = invoke("--help")
    assert result.returncode == 0
    assert "jj workspace creation/removal is unsupported" in result.stdout
    assert calls == []
    result, calls = invoke("workspace", "new", "task")
    assert result.returncode == 2
    assert calls == []
