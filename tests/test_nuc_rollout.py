"""Continuous NUC rollout selection through the real CLI and Git; GitHub is simulated."""

import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "scripts"))
import nuc_rollout  # noqa: E402

AGENTS = "c" * 40
GITHUB = r'''
import json, os, sys
from pathlib import Path
from urllib.parse import urlparse, parse_qs
args = sys.argv[1:]
assert args[:3] == ['api', '--hostname', 'github.com'], args
state_file = Path(os.environ['ROLLOUT_FIXTURE'])
state = json.loads(state_file.read_text())
path = urlparse(args[3]).path
query = parse_qs(urlparse(args[3]).query)
if '--method' in args:
    assert path.endswith('deploy-nuc.yml/dispatches'), path
    state.setdefault('dispatches', []).append(json.load(sys.stdin))
    state_file.write_text(json.dumps(state))
    sys.exit(0)
if path.endswith('/git/ref/heads/main'):
    result = {'object': {'sha': state['main']}}
elif path.endswith('ci.yml/runs'):
    runs = state.get('ci', [])
    if 'head_sha' in query:
        runs = sorted((r for r in runs if r['head_sha'] == query['head_sha'][0]), key=lambda r: -r['id'])[:1]
    result = {'workflow_runs': runs}
elif path.endswith('deploy-nuc.yml/runs'):
    result = {'workflow_runs': state.get('deploys', [])}
elif path.endswith('/actions/artifacts'):
    result = {'artifacts': [a for a in state.get('artifacts', []) if a['name'] == query['name'][0]]}
elif path.endswith('/artifacts'):
    result = {'artifacts': state.get('run_artifacts', {}).get(path.split('/')[-2], [])}
else:
    raise AssertionError(path)
print(json.dumps(result))
'''


class RolloutTests(unittest.TestCase):
    def setUp(self):
        temp = tempfile.TemporaryDirectory()
        self.addCleanup(temp.cleanup)
        self.root = Path(temp.name)
        self.repo = self.root / "repo"
        self.repo.mkdir()
        tools = self.root / "tools"
        tools.mkdir()
        (tools / "gh").write_text(f"#!{sys.executable}\n" + GITHUB)
        (tools / "gh").chmod(0o755)
        self.env = os.environ | {"PATH": f"{tools}{os.pathsep}{os.environ['PATH']}",
                                 "ROLLOUT_FIXTURE": str(self.root / "github.json"),
                                 "GITHUB_STEP_SUMMARY": str(self.root / "summary.md"),
                                 "NUC_ROLLOUT": "continuous"}
        self.git("init", "--quiet", "--initial-branch=main")
        self.git("config", "user.name", "Fixture")
        self.git("config", "user.email", "fixture@example.invalid")
        self.git("config", "commit.gpgsign", "false")
        self.state = {"ci": [], "artifacts": []}
        self.active = self.commit("active")
        self.save()

    def git(self, *args):
        return subprocess.check_output(["git", *args], cwd=self.repo, text=True).strip()

    def commit(self, message, ci=None, trailer=None):
        if trailer:
            message += f"\n\nNUC-Rollout: {trailer}"
        self.git("commit", "--quiet", "--allow-empty", "-m", message)
        sha = self.git("rev-parse", "HEAD")
        if ci:
            self.ci(sha, ci)
        return sha

    def ci(self, sha, conclusion):
        run_id = len(self.state["ci"]) + 1
        self.state["ci"].append({"id": run_id, "head_sha": sha, "head_branch": "main", "event": "push",
                                 "path": ".github/workflows/ci.yml",
                                 "status": "in_progress" if conclusion == "pending" else "completed",
                                 "conclusion": None if conclusion == "pending" else conclusion})

    def artifact(self, name, created="2026-11-19T00:00:00Z"):
        self.state["artifacts"].append({"name": name, "expired": False, "created_at": created})

    def save(self):
        (self.root / "github.json").write_text(json.dumps(self.state))

    def select(self, active=None):
        self.save()
        result = subprocess.run(
            [sys.executable, str(ROOT / "scripts/nuc_rollout.py"), "select",
             "--main", self.git("rev-parse", "HEAD"), "--configuration-revision",
             f"dotfiles={active or self.active};agents-workspace={AGENTS}"],
            cwd=self.repo, env=self.env, text=True, capture_output=True, timeout=30)
        self.assertEqual(result.returncode, 0, result.stderr)
        return json.loads(result.stdout)

    def test_newest_green_commit_supersedes_pending_and_older_revisions(self):
        self.commit("b", ci="success")
        c = self.commit("c", ci="success")
        red = self.commit("broken main", ci="failure")
        d = self.commit("d", ci="pending")
        result = self.select()
        self.assertEqual((result["outcome"], result["target"], result["superseded"]), ("selected", c, 2))
        self.assertEqual(result["skipped"], [
            {"sha": d, "reason": "ci_pending"}, {"sha": red, "reason": "ci_failure"}])

    def test_red_main_waits_for_a_green_fix_without_selecting_the_failed_sha(self):
        red = self.commit("broken main", ci="failure")
        self.assertEqual(self.select()["outcome"], "nothing_eligible")
        green = self.commit("fix forward", ci="success")
        self.assertNotEqual(red, green)
        self.assertEqual(self.select()["target"], green)

    def test_recheck_blocks_a_target_rerun_but_not_an_unrelated_red_main(self):
        target = self.commit("green target", ci="success")
        self.commit("newer red main", ci="failure")
        for state in ("success", "failure", "pending"):
            with self.subTest(target_ci=state):
                self.ci(target, state)
                self.save()
                result = subprocess.run(
                    [sys.executable, str(ROOT / "scripts/nuc_rollout.py"), "verify", "--sha", target],
                    cwd=self.repo, env=self.env, text=True, capture_output=True, timeout=30)
                if state == "success":
                    self.assertEqual(result.returncode, 0, result.stderr)
                    self.assertEqual(json.loads(result.stdout)["target"], target)
                else:
                    self.assertNotEqual(result.returncode, 0)
                    self.assertIn("Latest main-push CI", result.stderr)

    def test_newer_failed_rerun_hides_an_earlier_success(self):
        b = self.commit("b", ci="success")
        c = self.commit("c", ci="success")
        self.ci(c, "failure")
        self.assertEqual(self.select()["target"], b)

    def test_failure_marker_excludes_only_its_exact_sha(self):
        b = self.commit("b", ci="success")
        c = self.commit("c", ci="success")
        self.artifact(nuc_rollout.failed_marker(c))
        self.assertEqual(self.select()["target"], b)  # Never retry c itself.
        d = self.commit("d fix forward", ci="success")
        self.assertEqual(self.select()["target"], d)  # A green descendant of c is the retry.

    def test_publication_only_rides_along_but_never_triggers(self):
        self.commit("docs", ci="success", trailer="publication-only")
        p = self.commit("more docs", ci="success", trailer="publication-only")
        result = self.select()
        self.assertEqual((result["outcome"], result["head"]), ("nothing_to_activate", p))
        t = self.commit("service change", ci="success")
        self.assertEqual(self.select()["target"], t)

    def test_hold_stops_before_the_commit_until_a_human_passes_it(self):
        b = self.commit("b", ci="success")
        h = self.commit("risky", ci="success", trailer="hold")
        self.commit("after", ci="success")
        result = self.select()
        self.assertEqual((result["target"], result["held"]), (b, h))
        later = self.commit("later", ci="success")
        self.assertEqual(self.select(active=h)["target"], later)  # Manual exact deploy of h resumes.

    def test_hold_on_a_non_tip_commit_of_a_landing_still_holds(self):
        b = self.commit("b", ci="success")
        self.commit("first of two", trailer="hold")
        self.commit("tip of landing", ci="success")
        self.assertEqual(self.select()["target"], b)

    def test_unpublished_or_older_active_revision_never_downgrades(self):
        self.commit("b", ci="success")
        self.git("checkout", "--quiet", "--orphan", "other")
        other = self.commit("unpublished")
        self.git("checkout", "--quiet", "main")
        self.assertEqual(self.select(active=other)["outcome"], "diverged")
        self.assertEqual(self.select(active=self.git("rev-parse", "HEAD"))["outcome"], "current")

    def test_unknown_host_blocks_until_a_later_deployment(self):
        self.commit("b", ci="success")
        self.artifact("nuc-rollout-blocked", "2026-11-19T02:00:00Z")
        self.artifact("nuc-rollout-deployed", "2026-11-19T01:00:00Z")
        self.assertEqual(self.select()["outcome"], "blocked")
        self.artifact("nuc-rollout-deployed", "2026-11-19T03:00:00Z")
        self.assertEqual(self.select()["outcome"], "selected")

    def test_unknown_trailer_value_fails_closed(self):
        self.commit("b", ci="success", trailer="maybe")
        self.save()
        result = subprocess.run(
            [sys.executable, str(ROOT / "scripts/nuc_rollout.py"), "select", "--main",
             self.git("rev-parse", "HEAD"), "--configuration-revision",
             f"dotfiles={self.active};agents-workspace={AGENTS}"],
            cwd=self.repo, env=self.env, text=True, capture_output=True, timeout=30)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("Unknown NUC-Rollout trailer", result.stderr)

    def test_classification_reads_the_host_not_the_exit_status(self):
        prev, target, other = "a" * 40, "b" * 40, "d" * 40
        cases = [
            ("success", "success", target, "", "deployed"),
            ("failure", "skipped", prev, "nix-private-github: NUC deployment lock is held", "host_busy"),
            ("failure", "skipped", prev, "build failed", "not_activated"),
            ("failure", "skipped", target, "verification failed", "activated_unhealthy"),
            ("success", "failure", target, "", "activated_unhealthy"),
            ("success", "success", prev, "", "not_activated"),  # Exit 0 but nothing switched.
            ("failure", "skipped", other, "", "unknown"),
            ("failure", "skipped", None, "", "unknown"),
        ]
        for activation, health, active, log, expected in cases:
            with self.subTest(expected=expected, activation=activation, health=health):
                self.assertEqual(nuc_rollout.classify(prev, target, active, activation, health, log), expected)

    def test_report_fails_changed_services_even_when_activation_and_probes_succeeded(self):
        target = self.commit("service change", ci="success")
        readback = self.root / "readback.json"
        healthy = {"Id": "ok.service", "ActiveState": "active", "Result": "success"}
        failed = {"Id": "worker.service", "ActiveState": "failed", "Result": "exit-code"}
        for changed, outcome in [([healthy], "deployed"), ([healthy, failed], "activated_unhealthy")]:
            with self.subTest(outcome=outcome):
                readback.write_text(json.dumps({
                    "configurationRevision": f"dotfiles={target};agents-workspace={AGENTS}",
                    "changedUnits": changed, "failedUnits": ["unrelated.service"],
                }))
                result = subprocess.run(
                    [sys.executable, str(ROOT / "scripts/nuc_rollout.py"), "report",
                     "--previous", self.active, "--target", target, "--main", target,
                     "--activation", "success", "--health", "success", "--readback", str(readback)],
                    cwd=self.repo, env=self.env, text=True, capture_output=True, timeout=30,
                )
                self.assertEqual(result.returncode, 0, result.stderr)
                report = json.loads(result.stdout)
                self.assertEqual(report["outcome"], outcome)
                self.assertEqual(report["unhealthyChangedUnits"], [failed] if failed in changed else [])

    def dispatch(self, *args, **state):
        self.state.update(main=self.git("rev-parse", "HEAD"), **state)
        self.save()
        result = subprocess.run([sys.executable, str(ROOT / "scripts/nuc_rollout.py"), "dispatch", *args],
                                cwd=self.repo, env=self.env, text=True, capture_output=True, timeout=30)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.state = json.loads((self.root / "github.json").read_text())
        return json.loads(result.stdout)["state"]

    def test_dispatch_is_a_bounded_wake_up(self):
        main = self.commit("b", ci="pending")
        self.assertEqual(self.dispatch(), "main_ci_pending")
        self.state["ci"][-1].update(status="completed", conclusion="failure")
        queued = {"id": 5, "status": "queued", "conclusion": None, "display_title": "Deploy NUC x"}
        self.assertEqual(self.dispatch(deploys=[queued]), "deploy_pending")  # Never displace it.
        self.assertEqual(self.dispatch(deploys=[]), "rollout_requested")
        self.assertEqual(self.state["dispatches"], [
            {"ref": "main", "inputs": {"expected_sha": main, "operation": "rollout"}}])
        evaluated = {"id": 6, "status": "completed", "conclusion": "failure",
                     "display_title": f"Roll out NUC {main}", "html_url": "u"}
        self.assertEqual(self.dispatch(deploys=[evaluated]), "already_evaluated")  # No blind retry.
        self.assertEqual(self.dispatch(deploys=[evaluated | {"conclusion": "cancelled"}]),
                         "rollout_requested")
        deferred = evaluated | {"conclusion": "success"}
        artifacts = {"6": [{"name": "nuc-rollout-deferred"}]}
        # Completion events never retry a busy host; only the sweep does.
        self.assertEqual(self.dispatch(deploys=[deferred], run_artifacts=artifacts), "already_evaluated")
        self.assertEqual(self.dispatch("--retry-deferred", deploys=[deferred], run_artifacts=artifacts),
                         "rollout_requested")
        self.assertEqual(len(self.state["dispatches"]), 3)
        self.env["NUC_ROLLOUT"] = "paused"
        self.assertEqual(self.dispatch(deploys=[]), "rollout_disabled")
        self.assertEqual(len(self.state["dispatches"]), 3)


if __name__ == "__main__":
    unittest.main()
