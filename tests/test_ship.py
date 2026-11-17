"""Drive the shipping CLI and real Git remotes; simulate only GitHub's API/events."""

import json
import os
from pathlib import Path
import subprocess
import sys
import unittest

from tests import test_candidate_ci as fixtures

ROOT = Path(__file__).resolve().parents[1]

GITHUB = r'''
import json, os, subprocess, sys
from pathlib import Path
from urllib.parse import urlparse, parse_qs
args = sys.argv[1:]
root = Path(os.environ['SHIP_FIXTURE'])
state_file = root / 'github.json'
state = json.loads(state_file.read_text())
if args[:2] == ['run', 'download']:
    destination = Path(args[args.index('--dir') + 1])
    (destination / 'request.json').write_text(json.dumps(state['record']))
    sys.exit(0)
assert args[:3] == ['api', '--hostname', 'github.com'], args
endpoint = args[3]
path = urlparse(endpoint).path
query = parse_qs(urlparse(endpoint).query)
if '--method' in args:
    payload = json.load(sys.stdin)
    if path.endswith('/git/refs'):
        refs = state.setdefault('refs', {})
        assert payload['ref'] not in refs, 'claim already exists'
        refs[payload['ref']] = {'ref': payload['ref'], 'object': {'sha': payload['sha']}}
    elif path.endswith('/dispatches'):
        state.setdefault('dispatches', []).append({'path': path, 'payload': payload})
        state_file.write_text(json.dumps(state))
        if state.get('dispatch_error'):
            sys.exit('lost reply after dispatch')
    else:
        raise AssertionError(path)
    state_file.write_text(json.dumps(state))
    sys.exit(0)
if '/git/ref/heads/' in path:
    ref = path.split('/git/ref/heads/')[1]
    sha = subprocess.check_output(['git', '--git-dir', str(root / 'remote.git'),
                                   'rev-parse', 'refs/heads/' + ref], text=True).strip()
    result = {'object': {'sha': sha}}
elif '/git/matching-refs/' in path:
    ref = 'refs/' + path.split('/git/matching-refs/')[1]
    result = [value for key, value in state.get('refs', {}).items() if key.startswith(ref)]
elif path.endswith('ship.yml/runs'):
    result = [{'workflow_runs': state.get('requests', [])}]
elif path.endswith('/artifacts'):
    result = {'artifacts': state.get('artifacts', [])}
elif '/attempts/' in path:
    result = [{'jobs': state['jobs']}]
    if state.get('rerun'):
        state['run'].update(status='in_progress', conclusion=None, run_attempt=3)
        state_file.write_text(json.dumps(state))
elif path.endswith('ci.yml/runs'):
    run = state.get('main_run') if query['branch'] == ['main'] else state['run']
    result = {'workflow_runs': [run] if run else []}
else:
    raise AssertionError(path)
print(json.dumps(result))
'''


class ShipTests(unittest.TestCase):
    def setUp(self):
        self.fixture = fixtures.CandidateCiTests(methodName="runTest")
        self.fixture.setUp()
        self.addCleanup(self.fixture.doCleanups)
        self.f = self.fixture
        self.env = self.f.env | {"SHIP_FIXTURE": str(self.f.root),
                                 "GITHUB_SHA": self.f.base, "GITHUB_RUN_ID": "81",
                                 "GITHUB_RUN_ATTEMPT": "1"}
        gh = self.f.root / "tools/gh"
        gh.write_text(f"#!{sys.executable}\n" + GITHUB)
        self.assertEqual(self.f.cli("submit").returncode, 0)
        self.receipt = self.f.root / "receipt.json"
        self.receipt.write_text(json.dumps({"schemaVersion": 2, "status": "active",
                                           "authority": {"mode": "full"}, "keep": 17}))
        self.inputs = dict(base=self.f.base, sha=self.f.sha, deploy="true",
                           authority="human Ship approval", owner="https://ampcode.com/threads/owner")
        self.record = self.inputs | {"run": 81, "attempt": 1}
        self.f.state["record"] = self.record
        self.f.state["requests"] = [{
            "id": 81, "run_attempt": 1, "display_title": f"Ship {self.f.sha}",
            "head_sha": self.f.base, "head_branch": "main", "event": "workflow_dispatch",
            "path": ".github/workflows/ship.yml", "status": "completed", "conclusion": "success",
            "repository": {"full_name": fixtures.URL.removesuffix(".git").split("github.com/")[1]},
            "head_repository": {"full_name": "edmundmiller/dotfiles"},
        }]
        self.f.state["artifacts"] = [{"name": "ship-request-v1-1", "expired": False,
                                       "size_in_bytes": 512}]
        self.f.save()

    def state(self):
        return json.loads((self.f.root / "github.json").read_text())

    def cli(self, command, event=None, *args):
        if event is not None:
            path = self.f.root / "event.json"
            path.write_text(json.dumps(event))
            args = ("--event", str(path), *args)
        return subprocess.run([sys.executable, str(ROOT / "scripts/ship.py"), command, *args],
                              cwd=self.f.repo, env=self.env, text=True, capture_output=True, timeout=15)

    def event(self, main=False):
        run = self.f.state["run"] | {
            "repository": {"full_name": "edmundmiller/dotfiles"},
            "head_repository": {"full_name": "edmundmiller/dotfiles"},
        }
        if main:
            run["head_branch"] = "main"
        return {"workflow_run": run}

    def main_ci(self, conclusion="success", **changes):
        self.f.state = self.state()
        self.f.state["main_run"] = self.f.state["run"] | {"head_branch": "main",
                                                                    "conclusion": conclusion} | changes
        self.f.save()

    def test_archived_owner_does_not_block_landing_or_exact_main_deployment(self):
        # No Amp subscription, thread or process survives between these separate invocations.
        self.f.state["run"].update(status="in_progress", conclusion=None)
        self.f.save()
        result = self.cli("register", {"ref": "refs/heads/main", "inputs": self.inputs})
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(json.loads(result.stdout), self.record)
        result = self.cli("advance", self.event())
        self.assertEqual(json.loads(result.stdout)["state"], "candidate_ci_pending")
        self.assertEqual(self.f.remote_main(), self.f.base)
        self.f.state["run"].update(status="completed", conclusion="success")
        self.f.save()
        result = self.cli("advance", self.event())
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(json.loads(result.stdout)["state"], "main_ci_pending")
        self.assertEqual(self.f.remote_main(), self.f.sha)
        self.assertFalse(self.state().get("dispatches"))
        self.main_ci()
        result = self.cli("advance", self.event(main=True))
        self.assertEqual(result.returncode, 0, result.stderr)
        dispatches = self.state()["dispatches"]
        self.assertEqual(len(dispatches), 1)
        self.assertEqual(dispatches[0]["payload"], {"ref": "main", "inputs": {"expected_sha": self.f.sha}})
        self.assertNotEqual(self.cli("advance", self.event(main=True)).returncode, 0)
        self.assertEqual(len(self.state()["dispatches"]), 1)

    def test_ci_finished_before_registration_is_not_a_lost_event(self):
        self.f.state["artifacts"] = []
        self.f.state["requests"][0]["status"] = "in_progress"
        self.f.save()
        result = self.cli("advance", self.event())
        self.assertEqual(json.loads(result.stdout)["state"], "no_registered_request")
        result = self.cli("register", {"ref": "refs/heads/main", "inputs": self.inputs})
        self.assertEqual(result.returncode, 0, result.stderr)
        record = self.f.root / "request.json"
        record.write_text(result.stdout)
        result = self.cli("advance", {}, "--record", str(record))
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.f.remote_main(), self.f.sha)

    def test_expired_missing_and_mismatched_artifacts_fail_closed(self):
        original = self.state()
        for change in ({"artifacts": []},
                       {"artifacts": [original["artifacts"][0] | {"expired": True}]},
                       {"record": self.record | {"sha": self.f.base}},
                       {"record": self.record | {"attempt": 9}}):
            with self.subTest(change=change):
                self.f.state = original | change
                self.f.save()
                result = self.cli("advance", self.event())
                self.assertNotEqual(result.returncode, 0, result.stdout)
                self.assertEqual(self.f.remote_main(), self.f.base)

    def test_explicit_revocation_survives_completed_registration(self):
        result = self.cli("revoke", None, "--sha", self.f.sha)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.cli("revoke", None, "--sha", self.f.sha).returncode, 0)
        result = self.cli("advance", self.event())
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("revoked", result.stderr)
        self.assertEqual(self.f.remote_main(), self.f.base)
        self.assertFalse(self.state().get("dispatches"))

    def test_push_only_never_deploys_and_unregistered_push_never_lands(self):
        self.f.state["requests"] = []
        self.f.save()
        self.assertEqual(self.cli("advance", self.event()).returncode, 0)
        self.assertEqual(self.f.remote_main(), self.f.base)
        record = self.f.root / "request.json"
        record.write_text(json.dumps(self.record | {"deploy": "false"}))
        result = self.cli("advance", {}, "--record", str(record))
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.f.remote_main(), self.f.sha)
        self.assertNotIn(f"refs/tags/ship-deploy/{self.f.sha}", self.state().get("refs", {}))
        self.assertFalse(self.state().get("dispatches"))

    def test_bypassed_landing_cannot_resume_into_deployment(self):
        hook = self.f.remote / "hooks/post-receive"
        hook.write_text("#!/bin/sh\necho 'Bypassed rule violations for main' >&2\n")
        hook.chmod(0o755)
        result = self.cli("advance", self.event())
        self.assertNotEqual(result.returncode, 0, result.stdout)
        self.assertEqual(self.f.remote_main(), self.f.sha)
        self.main_ci()
        result = self.cli("advance", self.event(main=True))
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("compliant Ship landing is unproved", result.stderr)
        self.assertFalse(self.state().get("dispatches"))

    def test_candidate_failure_rerun_or_missing_context_never_lands(self):
        original = self.state()
        for change in ({"run": original["run"] | {"conclusion": "failure"}},
                       {"rerun": True}, {"jobs": original["jobs"][:1]}):
            with self.subTest(change=change):
                self.f.state = original | change
                self.f.save()
                self.assertNotEqual(self.cli("advance", self.event()).returncode, 0)
                self.assertEqual(self.f.remote_main(), self.f.base)
                self.assertFalse(self.state().get("dispatches"))

    def test_failed_cancelled_wrong_or_running_main_ci_never_deploys(self):
        self.assertEqual(self.cli("advance", self.event()).returncode, 0)
        for change in ({"conclusion": "failure"}, {"conclusion": "cancelled"},
                       {"head_sha": self.f.base}, {"event": "workflow_dispatch"},
                       {"path": ".github/workflows/other.yml"},
                       {"status": "in_progress", "conclusion": None}):
            with self.subTest(change=change):
                self.main_ci(**change)
                result = self.cli("advance", self.event(main=True))
                if change.get("status") == "in_progress":
                    self.assertEqual(json.loads(result.stdout)["state"], "main_ci_pending")
                else:
                    self.assertNotEqual(result.returncode, 0, result.stdout)
                self.assertFalse(self.state().get("dispatches"))

    def test_untrusted_cancelled_or_mismatched_request_never_lands(self):
        original = self.state()
        for change in ({"conclusion": "cancelled"}, {"head_branch": "other"},
                       {"path": ".github/workflows/other.yml"}, {"run_attempt": 2},
                       {"head_repository": {"full_name": "attacker/fork"}}):
            with self.subTest(change=change):
                self.f.state = original | {"requests": [original["requests"][0] | change]}
                self.f.save()
                result = self.cli("advance", self.event())
                self.assertEqual(self.f.remote_main(), self.f.base, result.stdout)
                self.assertFalse(self.state().get("dispatches"))

    def test_stale_main_and_unknown_deployment_dispatch_fail_visibly(self):
        self.assertEqual(self.cli("advance", self.event()).returncode, 0)
        self.main_ci()
        self.f.state = self.state() | {"dispatch_error": True}
        self.f.save()
        result = self.cli("advance", self.event(main=True))
        self.assertNotEqual(result.returncode, 0)
        self.assertIn(f"refs/tags/ship-deploy/{self.f.sha}", self.state()["refs"])
        self.assertNotEqual(self.cli("advance", self.event(main=True)).returncode, 0)
        self.assertEqual(len(self.state()["dispatches"]), 1)
        tree = self.f.git("rev-parse", "HEAD^{tree}")
        other = self.f.git("commit-tree", tree, "-p", self.f.sha, "-m", "other")
        self.f.git("push", "origin", f"{other}:refs/heads/main")
        result = self.cli("advance", self.event(main=True))
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("Main moved", result.stderr)
        self.assertEqual(self.f.remote_main(), other)

    def test_request_receipt_prevents_rearming_or_duplicate_uncertain_dispatch(self):
        args = ("--receipt", str(self.receipt), "--base", self.f.base, "--sha", self.f.sha,
                "--thread", self.inputs["owner"], "--authority", self.inputs["authority"])
        receipt = json.loads(self.receipt.read_text())
        receipt["authority"]["mode"] = "commit-push"
        self.receipt.write_text(json.dumps(receipt))
        self.assertNotEqual(self.cli("request", None, *args, "--deploy").returncode, 0)
        self.assertFalse(self.state().get("dispatches"))
        self.f.state = self.state() | {"dispatch_error": True}
        self.f.save()
        self.assertNotEqual(self.cli("request", None, *args).returncode, 0)
        self.assertNotEqual(self.cli("request", None, *args).returncode, 0)
        self.assertNotEqual(self.cli("request", None, *args, "--deploy").returncode, 0)
        self.assertEqual(len(self.state()["dispatches"]), 1)
        receipt = json.loads(self.receipt.read_text())
        self.assertEqual(receipt["keep"], 17)
        self.assertEqual(receipt["shipRequest"]["state"], "dispatch_unknown")


if __name__ == "__main__":
    unittest.main()
