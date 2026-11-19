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
    prefix = args[args.index('--name') + 1].rsplit('-', 1)[0]
    record = state.get('records', {}).get(args[2], {}).get(prefix, state['record'])
    (destination / 'request.json').write_text(json.dumps(record))
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
    refs = subprocess.check_output(['git', '--git-dir', str(root / 'remote.git'),
                                   'for-each-ref', '--format=%(refname) %(objectname)', ref], text=True)
    result += [{'ref': name, 'object': {'sha': sha}} for name, sha in
               (line.split() for line in refs.splitlines())]
elif '/git/tags/' in path:
    tag = subprocess.check_output(['git', '--git-dir', str(root / 'remote.git'),
                                  'cat-file', 'tag', path.rsplit('/', 1)[1]], text=True)
    header, message = tag.split('\n\n', 1)
    result = {'object': {'type': 'commit', 'sha': header.splitlines()[0].split()[1]},
              'message': message}
    result['object']['url'] = 'https://api.github.com/repos/edmundmiller/dotfiles/git/commits/' + result['object']['sha']
elif path.endswith('ship.yml/runs'):
    result = [{'workflow_runs': state.get('requests', [])}]
elif path.endswith('/artifacts'):
    result = {'artifacts': state.get('artifact_runs', {}).get(path.split('/')[-2], state.get('artifacts', []))}
elif '/actions/runs/' in path and '/attempts/' not in path:
    result = state.get('producers', {}).get(path.rsplit('/', 1)[1], state['requests'][0])
elif '/attempts/' in path and not path.endswith('/jobs'):
    identity = path.split('/actions/runs/')[1]
    result = state.get('producer_attempts', {}).get(identity,
        state.get('producers', {}).get(identity.split('/')[0], state['requests'][0]))
elif '/attempts/' in path:
    result = [{'jobs': state.get('job_runs', {}).get(path.split('/attempts/')[0].rsplit('/', 1)[1], state['jobs'])}]
    if state.get('rerun'):
        state['run'].update(status='in_progress', conclusion=None, run_attempt=3)
        state_file.write_text(json.dumps(state))
elif path.endswith('ci.yml/runs'):
    if query['event'] == ['workflow_dispatch']:
        runs = [run for run in state.get('platform_runs', [])
                if run['head_sha'] == query['head_sha'][0] and run['head_branch'] == query['branch'][0]]
    elif query['branch'] == ['main']:
        runs = [state['main_run']] if state.get('main_run') else []
    else:
        runs = [run for run in state.get('runs', [state['run']]) if run['head_sha'] == query['head_sha'][0]]
    result = {'workflow_runs': runs}
    if '--slurp' in args:
        result = [result]
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

    def test_standing_rollout_never_turns_task_approval_into_a_dispatch(self):
        self.env["NUC_ROLLOUT"] = "continuous"
        self.assertEqual(self.cli("advance", self.event()).returncode, 0)
        self.assertEqual(self.f.remote_main(), self.f.sha)
        self.main_ci()
        result = self.cli("advance", self.event(main=True))
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(json.loads(result.stdout)["deployment"], "standing_rollout")
        self.assertFalse(self.state().get("dispatches"))
        self.assertNotIn(f"refs/tags/ship-deploy/{self.f.sha}", self.state().get("refs", {}))

    def test_standing_rollout_requires_explicit_publication_only_commits(self):
        self.env["NUC_ROLLOUT"] = "continuous"
        inputs = self.inputs | {"deploy": "false"}
        result = self.cli("register", {"ref": "refs/heads/main", "inputs": inputs})
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("NUC-Rollout: publication-only", result.stderr)
        self.env["NUC_ROLLOUT"] = "paused"  # Without standing authority nothing changes.
        self.assertEqual(self.cli("register", {"ref": "refs/heads/main",
                                               "inputs": inputs}).returncode, 0)

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

    def enable_rebase(self, **options):
        self.inputs.update(allow_clean_rebase="true", deploy_rebased="true",
                           darwin="false", services_vm="false")
        self.inputs.update(options)
        result = self.cli("register", {"ref": "refs/heads/main", "inputs": self.inputs})
        self.assertEqual(result.returncode, 0, result.stderr)
        self.record = json.loads(result.stdout)
        self.f.state = self.state() | {"record": self.record}
        self.f.save()

    def move_main(self, conflict=False):
        head = self.f.git("rev-parse", "HEAD")
        self.f.git("checkout", "--detach", self.f.remote_main())
        name = "file" if conflict else "independent"
        path = self.f.repo / name
        path.write_text((path.read_text() if path.exists() else "") + "new main change\n")
        self.f.git("add", name)
        self.f.git("commit", "--quiet", "-m", "independent main advance")
        main = self.f.git("rev-parse", "HEAD")
        self.f.git("push", "origin", f"{main}:refs/heads/main")
        self.f.git("checkout", "--detach", head)
        return main

    def prepare_successor(self, event=None):
        self.successor = self.f.root / "successor/request.json"
        self.successor.unlink(missing_ok=True)
        result = self.cli("advance", event or self.event(), "--successor", str(self.successor))
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(json.loads(result.stdout)["state"], "rebase_prepared")
        return json.loads(self.successor.read_text())

    def upload_successor(self, record):
        self.f.state = self.state()
        run_id = str(record["run"])
        self.f.state.setdefault("producers", {})[run_id] = self.f.state["requests"][0] | {
            "id": record["run"], "head_sha": self.f.remote_main(),
            "event": "workflow_run", "run_attempt": record["attempt"],
        }
        self.f.state.setdefault("records", {}).setdefault(run_id, {})["ship-successor-v2"] = record
        artifacts = self.f.state.setdefault("artifact_runs", {}).setdefault(
            run_id, list(self.f.state["artifacts"]) if record["run"] == 81 else [],
        )
        artifacts.append({"name": f"ship-successor-v2-{record['attempt']}",
                          "expired": False, "size_in_bytes": 512})
        self.f.save()

    def successor_ci(self, record, **changes):
        self.f.state = self.state()
        self.f.state["run"] = self.f.state["run"] | {
            "id": 17 + record["generation"], "head_sha": record["sha"],
            "head_branch": f"candidate/{record['base']}/{record['sha']}",
            "status": "completed", "conclusion": "success", "run_attempt": 1,
        } | changes
        self.f.save()

    def replace_candidate(self, sha):
        self.f.sha = sha
        self.f.branch = f"candidate/{self.f.base}/{sha}"
        self.inputs["sha"] = sha
        self.f.state["run"].update(head_sha=sha, head_branch=self.f.branch)
        self.f.state["requests"][0]["display_title"] = f"Ship {sha}"
        self.f.save()
        self.assertEqual(self.f.cli("submit").returncode, 0)

    def test_clean_replay_preserves_four_commits_and_requires_new_candidate_and_main_ci(self):
        for number in range(2, 5):
            (self.f.repo / f"task-{number}").write_text(f"task change {number}\n")
            self.f.git("add", f"task-{number}")
            self.f.git("commit", "--quiet", "-m", f"task commit {number}")
        self.replace_candidate(self.f.git("rev-parse", "HEAD"))
        self.enable_rebase()
        original_event = self.event()
        main = self.move_main()
        original_head = self.f.git("rev-parse", "HEAD")
        record = self.prepare_successor()
        self.assertEqual(record["base"], main)
        self.assertEqual(self.f.git("rev-list", "--count", f"{main}..{record['sha']}"), "4")
        self.assertEqual(self.f.git("show", f"{record['sha']}:independent"), "new main change")
        self.assertEqual(self.f.git("show", f"{record['sha']}:task-4"), "task change 4")
        self.assertEqual(self.f.git("show", f"{record['sha']}:file"), "candidate")
        self.assertEqual(self.f.git("rev-parse", "HEAD"), original_head)
        self.assertEqual(self.f.remote_main(), main)
        # A locator/candidate must not be exposed before authority is retained.
        result = self.cli("publish-successor", None, "--record", str(self.successor))
        self.assertNotEqual(result.returncode, 0)
        self.upload_successor(record)
        result = self.cli("publish-successor", None, "--record", str(self.successor))
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(json.loads(result.stdout)["state"], "candidate_ci_pending")
        self.assertEqual(self.f.remote_main(), main)
        self.assertEqual(self.cli("advance", original_event).returncode, 0)
        self.assertEqual(self.f.remote_main(), main)
        self.successor_ci(record)
        result = self.cli("advance", self.event())
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(json.loads(result.stdout)["state"], "main_ci_pending")
        self.assertEqual(self.f.remote_main(), record["sha"])
        self.assertEqual(self.f.git("rev-parse", "HEAD"), original_head)
        self.assertFalse(self.state().get("dispatches"))
        self.main_ci(head_sha=self.f.sha)  # Old green main CI is not successor evidence.
        self.assertNotEqual(self.cli("advance", self.event(main=True)).returncode, 0)
        self.assertFalse(self.state().get("dispatches"))
        self.main_ci(head_sha=record["sha"])
        result = self.cli("advance", self.event(main=True))
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.state()["dispatches"][0]["payload"],
                         {"ref": "main", "inputs": {"expected_sha": record["sha"]}})
        self.assertNotEqual(self.cli("advance", self.event(main=True)).returncode, 0)
        self.assertEqual(len(self.state()["dispatches"]), 1)

    def test_v1_stays_exact_and_v2_requires_explicit_rebased_deployment_approval(self):
        self.inputs["allow_clean_rebase"] = "true"
        result = self.cli("register", {"ref": "refs/heads/main", "inputs": self.inputs})
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("explicit --deploy-rebased", result.stderr)
        main = self.move_main()
        result = self.cli("advance", self.event())
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("Main moved", result.stderr)
        # Registration is allowed to capture descendant main only with v2 authority.
        self.env["GITHUB_SHA"] = main
        self.enable_rebase()
        self.assertEqual(self.record["registeredHead"], main)
        self.assertEqual(self.record["base"], self.f.base)
        self.f.state["requests"][0]["head_sha"] = main
        self.f.save()
        self.prepare_successor()

    def test_conflicting_or_failed_candidate_cannot_be_rebased(self):
        self.enable_rebase()
        main = self.move_main(conflict=True)
        path = self.f.root / "successor/request.json"
        result = self.cli("advance", self.event(), "--successor", str(path))
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("conflict or empty commit", result.stderr)
        self.assertFalse(path.exists())
        self.assertEqual(self.f.remote_main(), main)
        self.f.state["run"]["conclusion"] = "failure"
        self.f.save()
        result = self.cli("advance", self.event(), "--successor", str(path))
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("CI is not successful", result.stderr)

    def test_successors_inherit_revocation_expiry_and_artifact_trust(self):
        self.enable_rebase()
        main = self.move_main()
        record = self.prepare_successor()
        self.upload_successor(record)
        self.assertEqual(self.cli("publish-successor", None, "--record", str(self.successor)).returncode, 0)
        self.successor_ci(record)
        original = self.state()
        for change in (
            {"record": self.record | {"createdAt": "2000-01-01T00:00:00+00:00"}},
            {"records": {"81": {"ship-successor-v2": record | {"previousSha": main}}}},
            {"artifact_runs": {"81": original["artifacts"]}},
            {"producers": {"81": original["producers"]["81"] | {"head_branch": "attacker"}}},
            {"run": original["run"] | {"conclusion": "failure"}},
        ):
            with self.subTest(change=change):
                self.f.state = original | change
                self.f.save()
                result = self.cli("advance", self.event())
                self.assertNotEqual(result.returncode, 0, result.stdout)
                self.assertEqual(self.f.remote_main(), main)
        self.f.state = original
        self.f.save()
        self.assertEqual(self.cli("revoke", None, "--sha", self.f.sha).returncode, 0)
        result = self.cli("advance", self.event())
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("revoked", result.stderr)
        self.assertEqual(self.f.remote_main(), main)

    def test_producer_retry_preserves_its_original_immutable_successor(self):
        self.enable_rebase()
        main = self.move_main()
        self.env["GITHUB_RUN_ID"] = "82"
        record = self.prepare_successor()
        self.upload_successor(record)
        self.assertEqual(self.cli("publish-successor", None, "--record", str(self.successor)).returncode, 0)
        self.successor_ci(record)
        self.f.state = self.state()
        original_attempt = self.f.state["producers"]["82"] | {"conclusion": "failure"}
        self.f.state["producer_attempts"] = {"82/attempts/1": original_attempt}
        self.f.state["producers"]["82"].update(run_attempt=2, conclusion="cancelled")
        self.f.save()
        self.env["GITHUB_RUN_ID"] = "83"
        original = self.state()
        for change in ({"run_attempt": 2}, {"head_branch": "candidate/attacker"},
                       {"conclusion": "cancelled"}):
            with self.subTest(change=change):
                self.f.state = original | {"producer_attempts": {
                    "82/attempts/1": original_attempt | change,
                }}
                self.f.save()
                self.assertNotEqual(self.cli("advance", self.event()).returncode, 0)
                self.assertEqual(self.f.remote_main(), main)
        self.f.state = original
        self.f.save()
        result = self.cli("advance", self.event())
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(json.loads(result.stdout)["state"], "main_ci_pending")
        self.assertEqual(self.f.remote_main(), record["sha"])
        self.assertFalse(self.state().get("dispatches"))

    def test_rebase_budget_and_no_deploy_survive_repeated_main_advances(self):
        self.enable_rebase(deploy="false", deploy_rebased="false")
        for generation in range(1, 4):
            self.move_main()
            self.env["GITHUB_RUN_ID"] = str(81 + generation)
            record = self.prepare_successor()
            self.upload_successor(record)
            if generation == 1:
                first_sha = record["sha"]
            if generation == 3:
                # Revocation during upload must cover ancestors, not just the tip/root.
                before_revocation = self.state()
                self.assertEqual(self.cli("revoke", None, "--sha", first_sha).returncode, 0)
                result = self.cli("publish-successor", None, "--record", str(self.successor))
                self.assertNotEqual(result.returncode, 0)
                self.assertIn("revoked", result.stderr)
                branch = f"refs/heads/candidate/{record['base']}/{record['sha']}"
                self.assertEqual(self.f.git("ls-remote", "origin", branch), "")
                self.f.state = before_revocation
                self.f.save()
            result = self.cli("publish-successor", None, "--record", str(self.successor))
            self.assertEqual(result.returncode, 0, result.stderr)
            self.successor_ci(record)
        main = self.move_main()
        result = self.cli("advance", self.event(), "--successor", str(self.successor))
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("limit reached", result.stderr)
        self.assertEqual(self.f.remote_main(), main)
        self.assertFalse(self.state().get("dispatches"))

    def test_merge_candidate_is_not_flattened_during_replay(self):
        tree = self.f.git("rev-parse", "HEAD^{tree}")
        side = self.f.git("commit-tree", tree, "-p", self.f.base, "-m", "side")
        merge = self.f.git("commit-tree", tree, "-p", self.f.sha, "-p", side, "-m", "merge")
        self.f.git("checkout", "--detach", merge)
        self.replace_candidate(merge)
        self.enable_rebase()
        main = self.move_main()
        path = self.f.root / "successor/request.json"
        result = self.cli("advance", self.event(), "--successor", str(path))
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("does not accept merge commits", result.stderr)
        self.assertFalse(path.exists())
        self.assertEqual(self.f.remote_main(), main)

    def test_equivalent_main_change_cannot_silently_drop_a_task_commit(self):
        self.enable_rebase()
        self.move_main()
        head = self.f.git("rev-parse", "HEAD")
        self.f.git("checkout", "--detach", self.f.remote_main())
        (self.f.repo / "file").write_text("candidate\n")
        self.f.git("add", "file")
        self.f.git("commit", "--quiet", "-m", "equivalent change on main")
        main = self.f.git("rev-parse", "HEAD")
        self.f.git("push", "origin", f"{main}:refs/heads/main")
        self.f.git("checkout", "--detach", head)
        path = self.f.root / "successor/request.json"
        result = self.cli("advance", self.event(), "--successor", str(path))
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("conflict or empty commit", result.stderr)
        self.assertFalse(path.exists())
        self.assertEqual(self.f.remote_main(), main)

    def test_duplicate_successor_producer_cannot_replace_the_chosen_generation(self):
        self.enable_rebase()
        main = self.move_main()
        record = self.prepare_successor()
        self.upload_successor(record)
        self.assertEqual(self.cli("publish-successor", None, "--record", str(self.successor)).returncode, 0)
        self.env["GITHUB_RUN_ID"] = "82"
        competing = record | {"run": 82}
        self.successor.write_text(json.dumps(competing))
        self.upload_successor(competing)
        result = self.cli("publish-successor", None, "--record", str(self.successor))
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("Another generation already owns", result.stderr)
        self.successor_ci(record)
        result = self.cli("advance", self.event())
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.f.remote_main(), record["sha"])
        self.assertNotEqual(main, record["sha"])

    def test_publication_only_successor_lands_without_deployment_authority(self):
        self.enable_rebase(deploy="false", deploy_rebased="false")
        self.move_main()
        record = self.prepare_successor()
        self.upload_successor(record)
        self.assertEqual(self.cli("publish-successor", None, "--record", str(self.successor)).returncode, 0)
        self.successor_ci(record)
        result = self.cli("advance", self.event())
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(json.loads(result.stdout), {
            "state": "published", "sha": record["sha"], "deployment": "not_authorized",
        })
        self.main_ci(head_sha=record["sha"])
        self.assertEqual(self.cli("advance", self.event(main=True)).returncode, 0)
        self.assertFalse(self.state().get("dispatches"))
        self.assertEqual(self.f.remote_main(), record["sha"])

    def test_main_moving_after_landing_cannot_reopen_rebasing(self):
        self.enable_rebase()
        self.assertEqual(self.cli("advance", self.event()).returncode, 0)
        self.main_ci()
        main = self.move_main()
        path = self.f.root / "successor/request.json"
        result = self.cli("advance", self.event(main=True), "--successor", str(path))
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("Main moved", result.stderr)
        self.assertFalse(path.exists())
        self.assertFalse(self.state().get("dispatches"))
        self.assertEqual(self.f.remote_main(), main)

    def test_unproved_landing_still_cannot_replay_after_main_moves(self):
        self.enable_rebase()
        hook = self.f.remote / "hooks/post-receive"
        hook.write_text("#!/bin/sh\necho 'Bypassed rule violations for main' >&2\n")
        hook.chmod(0o755)
        self.assertNotEqual(self.cli("advance", self.event()).returncode, 0)
        self.assertEqual(self.f.remote_main(), self.f.sha)
        main = self.move_main()
        path = self.f.root / "successor/request.json"
        result = self.cli("advance", self.event(), "--successor", str(path))
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("may already be published", result.stderr)
        self.assertFalse(path.exists())
        self.assertFalse(self.state().get("dispatches"))
        self.assertEqual(self.f.remote_main(), main)

    def test_selected_native_profiles_require_fresh_correlated_success(self):
        self.enable_rebase(darwin="true", services_vm="true")
        result = self.cli("advance", self.event())
        self.assertEqual(json.loads(result.stdout)["state"], "platform_ci_pending")
        dispatch = self.state()["dispatches"][0]["payload"]
        self.assertEqual(dispatch["inputs"]["darwin"], "true")
        self.assertEqual(dispatch["inputs"]["services_vm"], "true")
        result = self.cli("advance", self.event())
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("dispatch already claimed", result.stderr)
        self.assertEqual(len(self.state()["dispatches"]), 1)
        self.f.state = self.state()
        manual = self.f.state["run"] | {"event": "workflow_dispatch", "id": 29,
            "display_title": f"Ship validation {dispatch['inputs']['ship_request']}"}
        self.f.state["platform_runs"] = [manual]
        jobs = self.f.state["jobs"] + [{"name": "Darwin-only checks", "conclusion": "success"},
                                    {"name": "Service VM Tests (Linux)", "conclusion": "skipped"}]
        self.f.state["job_runs"] = {"29": jobs}
        self.f.save()
        self.assertNotEqual(self.cli("advance", self.event()).returncode, 0)
        self.assertEqual(self.f.remote_main(), self.f.base)
        jobs[-1]["conclusion"] = "success"
        self.f.save()
        main = self.move_main()
        record = self.prepare_successor({"workflow_run": self.event()["workflow_run"] | manual})
        self.upload_successor(record)
        self.assertEqual(self.cli("publish-successor", None, "--record", str(self.successor)).returncode, 0)
        self.successor_ci(record)
        result = self.cli("advance", self.event())
        self.assertEqual(json.loads(result.stdout)["state"], "platform_ci_pending")
        self.assertEqual(self.f.remote_main(), main)
        dispatch = self.state()["dispatches"][-1]["payload"]
        self.assertEqual(len(self.state()["dispatches"]), 2)
        self.assertTrue(dispatch["inputs"]["ship_request"].endswith(record["sha"]))
        self.f.state = self.state()
        native = self.f.state["run"] | {"event": "workflow_dispatch", "id": 30,
            "display_title": f"Ship validation {dispatch['inputs']['ship_request']}"}
        self.f.state["platform_runs"].insert(0, native)
        self.f.state["job_runs"]["30"] = jobs
        self.f.save()
        result = self.cli("advance", {"workflow_run": self.event()["workflow_run"] | native})
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.f.remote_main(), record["sha"])

    def test_unknown_native_dispatch_stays_claimed_and_requires_recovery(self):
        self.enable_rebase(darwin="true")
        self.f.state = self.state() | {"dispatch_error": True}
        self.f.save()
        self.assertNotEqual(self.cli("advance", self.event()).returncode, 0)
        self.assertEqual(len(self.state()["dispatches"]), 1)
        result = self.cli("advance", self.event())
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("dispatch already claimed", result.stderr)
        self.assertIn("Do not redispatch", result.stderr)
        self.assertEqual(len(self.state()["dispatches"]), 1)
        self.assertEqual(self.f.remote_main(), self.f.base)


if __name__ == "__main__":
    unittest.main()
