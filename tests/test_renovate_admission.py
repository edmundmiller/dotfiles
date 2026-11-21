"""Public controller CLI with real Git transport; GitHub/registry/tooling are fixtures."""

import copy
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
URL = "https://github.com/edmundmiller/dotfiles.git"
PACKAGE = "packages/callstack-diff/"
LINT = "oxlint-tsgolint"
LINT_BRANCH = "renovate/callstack-tsgolint-patches"
LINT_BINARIES = {f"@oxlint-tsgolint/{platform}-{arch}": {"os": platform, "cpu": arch}
                 for platform in ("darwin", "linux", "win32") for arch in ("arm64", "x64")}


class TypesAdmissionTests(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        self.temp = Path(temporary.name)
        self.repo = self.temp / "repo"
        self.repo.mkdir()
        self.git("init", "--quiet", "--initial-branch=main")
        self.git("config", "user.name", "Fixture")
        self.git("config", "user.email", "fixture@example.invalid")
        self.git("config", "commit.gpgsign", "false")
        self.git("config", "core.hooksPath", "/dev/null")
        for name in ("candidate_ci.py", "renovate_admission.py"):
            self.write("scripts/" + name, (ROOT / "scripts" / name).read_text())
        self.write(".github/workflows/renovate-admission.yml", "trusted workflow\n")
        self.write("renovate.json", (ROOT / "renovate.json").read_text())
        self.write(PACKAGE + "package.json", json.dumps({
            "devDependencies": {"@types/bun": "1.3.13", LINT: "7.0.2001"},
            "dependencies": {"runtime": "2.0.0"}, "scripts": {"test": "trusted"},
        }))
        self.lock = {"workspaces": {"": {"devDependencies": {"@types/bun": "1.3.13"}}},
                     "packages": {name: [f"{name}@1.3.13", "", metadata, "sha512-" + "a" * 86 + "=="]
                                  for name, metadata in (
                                      ("@types/bun", {"dependencies": {"bun-types": "1.3.13"}}),
                                      ("bun-types", {"dependencies": {"@types/node": "*"}}))}}
        self.lock["packages"]["undici-types"] = ["undici-types@8.3.0", "", {}, "sha512-" + "b" * 86 + "=="]
        self.lock["workspaces"][""]["devDependencies"][LINT] = "7.0.2001"
        for name, metadata in LINT_BINARIES.items():
            self.lock["packages"][name] = [f"{name}@7.0.2001", "", metadata, "sha512-" + "c" * 86 + "=="]
        self.lock["packages"][LINT] = [
            f"{LINT}@7.0.2001", "", {"optionalDependencies": dict.fromkeys(LINT_BINARIES, "7.0.2001"),
                                   "bin": {"tsgolint": "./bin/tsgolint.js"}}, "sha512-" + "d" * 86 + "==",
        ]
        self.write(PACKAGE + "bun.lock", json.dumps(self.lock))
        self.write(PACKAGE + "bun.nix", "generated 1.3.13\n")
        self.git("add", ".")
        self.git("commit", "--quiet", "-m", "enable pilot", env={
            "GIT_AUTHOR_DATE": "2024-01-01T00:00:00Z", "GIT_COMMITTER_DATE": "2024-01-01T00:00:00Z"})
        self.base = self.git("rev-parse", "HEAD")
        remote = self.temp / "remote.git"
        subprocess.run(["git", "init", "--bare", "--quiet", str(remote)], check=True)
        self.git("remote", "add", "origin", URL)
        self.git("config", f"url.{remote}.insteadOf", URL)
        self.git("push", "origin", "HEAD:refs/heads/main")
        manifest = json.loads((self.repo / PACKAGE / "package.json").read_text())
        manifest["devDependencies"]["@types/bun"] = "1.3.14"
        self.write(PACKAGE + "package.json", json.dumps(manifest))
        self.git("commit", "--quiet", "-am", "proposal")
        source = self.git("rev-parse", "HEAD")
        self.git("push", "origin", "HEAD:refs/heads/renovate/callstack-types-patches")
        self.git("reset", "--hard", self.base)
        self.state = {
            "pr": {"number": 301, "created_at": "2024-01-02T00:00:00Z", "state": "open",
                   "draft": False, "auto_merge": None, "base": {"ref": "main"},
                   "head": {"ref": "renovate/callstack-types-patches", "sha": source,
                            "repo": {"full_name": "edmundmiller/dotfiles"}},
                   "labels": [{"name": n} for n in ("dependencies", "javascript", "renovate-types-pilot")]},
            "files": [{"filename": PACKAGE + "package.json"}], "statuses": [],
            "released": "2024-01-01T00:00:00Z", "outstanding": [],
            "origin": {"path": ".github/workflows/renovate-admission.yml", "event": "workflow_run",
                       "head_sha": self.base, "head_branch": "main", "run_attempt": 1,
                       "status": "completed", "conclusion": "success"},
        }
        self.save()
        tools = self.temp / "tools"
        tools.mkdir()
        self.tools = tools
        common = f"#!{sys.executable}\nimport json, os, sys\nfrom pathlib import Path\n"
        self.tool("nix", common + f"print({str(tools.parent)!r})\n")
        self.tool("bun", common + '''
assert not os.environ.get('GH_TOKEN'), 'credential escaped into dependency tooling'
if '-e' in sys.argv:
    print(json.dumps(json.load(sys.stdin)))
else:
    deps = json.loads(Path('package.json').read_text())['devDependencies']
    lock = json.loads(Path('bun.lock').read_text())
    before = lock['workspaces']['']['devDependencies']
    if deps['@types/bun'] != before['@types/bun']:
        version = deps['@types/bun']
        before['@types/bun'] = version
        for name in ('@types/bun', 'bun-types'):
            lock['packages'][name][0] = name + '@' + version
        lock['packages']['@types/bun'][2]['dependencies']['bun-types'] = version
        if version == '1.4.4':
            lock['packages']['bun-types'][2]['dependencies']['undici-types'] = '*'
    if deps['oxlint-tsgolint'] != before['oxlint-tsgolint']:
        version = deps['oxlint-tsgolint']
        before['oxlint-tsgolint'] = version
        lock['packages']['oxlint-tsgolint'][0] = 'oxlint-tsgolint@' + version
        optional = lock['packages']['oxlint-tsgolint'][2]['optionalDependencies']
        for name in optional:
            optional[name] = version
            lock['packages'][name][0] = name + '@' + version
    Path('bun.lock').write_text(json.dumps(lock))
''')
        self.tool("bun2nix", common + '''
assert not os.environ.get('GH_TOKEN'), 'credential escaped into generation'
args = sys.argv
lock = json.loads(Path(args[args.index('-l') + 1]).read_text())
deps = lock['workspaces']['']['devDependencies']
Path(args[args.index('-o') + 1]).write_text('generated ' + json.dumps(deps, sort_keys=True) + '\\n')
''')
        for name in ("deadnix", "nixfmt"):
            self.tool(name, common + "assert not os.environ.get('GH_TOKEN')\n")
        self.tool("curl", common + f"state=json.loads(Path({str(self.temp / 'github.json')!r}).read_text())\n" + '''
release = state.get('registry_times', {}).get(sys.argv[-1].split('registry.npmjs.org/')[-1], state['released'])
print(json.dumps({'time': {v: release for v in ('1.3.14', '1.4.0', '1.4.4', '7.0.2002')}}))
''')
        self.tool("gh", common + '''
state = json.loads(Path(os.environ['TYPES_FIXTURE']).read_text())
args = sys.argv[1:]
if args[:2] == ['run','download']:
    Path(args[args.index('--dir')+1], 'record.json').write_text(json.dumps(state['record']))
    sys.exit(0)
assert args[:3] == ['api','--hostname','github.com'], args
endpoint = args[3]
if 'head=edmundmiller:renovate/callstack-tsgolint-patches' in endpoint:
    result = [state['lint_pr']] if 'lint_pr' in state else []
elif '/pulls?' in endpoint: result = state.get('prs', [state['pr']])
elif '/files?' in endpoint: result = [state['files']]
elif endpoint.endswith('/pulls/302'): result = state['lint_pr']
elif '/pulls/' in endpoint: result = state['pr']
elif endpoint.endswith('/status'): result = {'statuses':state['statuses']}
elif '/matching-refs/' in endpoint: result = state['outstanding']
elif endpoint.endswith('/actions/runs/7'): result = state['origin']
elif '/check-runs?' in endpoint: result = [{'check_runs':state['checks']}]
elif '/attempts/' in endpoint:
    result = [{'jobs':state['jobs']}]
    if state.get('rerun'):
        state['run'].update(status='in_progress', conclusion=None, run_attempt=3)
        Path(os.environ['TYPES_FIXTURE']).write_text(json.dumps(state))
elif '/actions/workflows/' in endpoint: result = {'workflow_runs':[state['run']]}
elif endpoint == 'repos/edmundmiller/dotfiles': result = {'permissions':{'push':True}}
else: raise AssertionError(endpoint)
print(json.dumps(result))
''')
        # tools() expects <returned store path>/bin; fake tools live here.
        (self.temp / "bin").symlink_to(tools)
        self.env = os.environ | {"PATH": str(tools) + os.pathsep + os.environ["PATH"],
                                  "TYPES_FIXTURE": str(self.temp / "github.json"),
                                  "GH_TOKEN": "write-credential-fixture", "GITHUB_RUN_ID": "7",
                                  "GITHUB_RUN_ATTEMPT": "1"}

    def write(self, name, content):
        path = self.repo / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(content)
        return path

    def tool(self, name, content):
        path = self.tools / name
        path.write_text(content)
        path.chmod(0o755)

    def git(self, *args, env=None):
        return subprocess.check_output(["git", *args], cwd=self.repo, text=True,
                                       stderr=subprocess.PIPE, env=os.environ | (env or {})).strip()

    def save(self):
        (self.temp / "github.json").write_text(json.dumps(self.state))

    def cli(self, *args):
        return subprocess.run([sys.executable, str(self.repo / "scripts/renovate_admission.py"), *args],
                              cwd=self.repo, env=self.env, text=True, capture_output=True, timeout=20)

    def prepare(self, version=None):
        selected = self.cli("select", *(["--version", version] if version else []))
        self.assertEqual(selected.returncode, 0, selected.stderr)
        selection = self.temp / "selection.json"
        selection.write_text(selected.stdout)
        bundle = self.temp / "bundle"
        result = self.cli("prepare", "--selection", str(selection), "--output", str(bundle))
        self.assertEqual(result.returncode, 0, result.stderr)
        self.git("reset", "--hard", self.base)
        return bundle

    def candidate(self, version=None):
        bundle = self.prepare(version)
        staged = self.cli("stage", "--bundle", str(bundle))
        self.assertEqual(staged.returncode, 0, staged.stderr)
        record = json.loads(staged.stdout)
        self.state["record"] = record
        sha = record["sha"]
        self.branch = f"candidate/{self.base}/{sha}"
        self.state["run"] = {"id": 17, "run_attempt": 2, "head_sha": sha,
                             "head_branch": self.branch, "event": "push",
                             "path": ".github/workflows/ci.yml", "status": "completed",
                             "conclusion": "success", "html_url": "https://example.invalid/run/17"}
        self.state["checks"] = [{"name": n, "app": {"id":15368}, "conclusion":"success"}
                                for n in ("Flake Check (Linux)", "Check Formatting")]
        self.state["jobs"] = [{"name": n["name"], "conclusion":"success"} for n in self.state["checks"]]
        self.save()
        record_file = self.temp / "record.json"
        record_file.write_text(staged.stdout)
        submitted = self.cli("submit", "--record", str(record_file))
        self.assertEqual(submitted.returncode, 0, submitted.stderr)
        self.git("checkout", "--detach", self.base)
        return sha

    def landing(self):
        self.save()
        event = self.temp / "event.json"
        event.write_text(json.dumps({"workflow_run": self.state["run"]}))
        return self.cli("land", "--event", str(event))

    def remote_main(self):
        return self.git("ls-remote", "origin", "refs/heads/main").split()[0]

    def lint_proposal(self, version="7.0.2002"):
        if "lint_pr" in self.state:
            self.git("checkout", LINT_BRANCH)
        else:
            self.git("checkout", "-b", LINT_BRANCH, self.base)
        manifest = json.loads((self.repo / PACKAGE / "package.json").read_text())
        manifest["devDependencies"][LINT] = version
        self.write(PACKAGE + "package.json", json.dumps(manifest))
        self.git("commit", "--quiet", "-am", "lint patch proposal")
        source = self.git("rev-parse", "HEAD")
        self.git("push", "origin", f"HEAD:refs/heads/{LINT_BRANCH}")
        self.state["lint_pr"] = copy.deepcopy(self.state["pr"])
        self.state["lint_pr"].update(number=302, labels=[
            {"name": name} for name in ("dependencies", "javascript", "renovate-lint-pilot")
        ])
        self.state["lint_pr"]["head"].update(ref=LINT_BRANCH, sha=source)
        self.git("checkout", "--detach", self.base)
        self.save()

    def test_prepare_submit_and_exact_land_without_merge_or_credential_escape(self):
        sha = self.candidate()
        self.assertEqual(self.remote_main(), self.base)
        result = self.landing()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.remote_main(), sha)
        self.assertEqual(self.git("rev-parse", "HEAD"), sha)
        self.assertEqual(set(self.git("diff", "--name-only", self.base, sha).splitlines()),
                         {PACKAGE + name for name in ("package.json", "bun.lock", "bun.nix")})
        result = self.cli("select")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(json.loads(result.stdout), {"selected": False})

    def test_existing_held_young_or_artifact_failed_proposals_never_submit(self):
        original = copy.deepcopy(self.state)
        for case in ("existing", "hold", "draft", "artifacts", "young", "busy", "workflow"):
            self.state = copy.deepcopy(original)
            if case == "existing": self.state["pr"]["created_at"] = "2023-12-31T23:59:59Z"
            if case == "hold": self.state["pr"]["labels"].append({"name":"security-hold"})
            if case == "draft": self.state["pr"]["draft"] = True
            if case == "artifacts": self.state["statuses"] = [{"context":"renovate/artifacts", "state":"failure"}]
            if case == "young": self.state["released"] = "2099-01-01T00:00:00Z"
            if case == "busy": self.state["outstanding"] = [{"ref":"another candidate"}]
            if case == "workflow": self.state["files"].append({"filename":".github/workflows/ci.yml"})
            self.save()
            with self.subTest(case=case):
                self.assertNotEqual(self.cli("select").returncode, 0)
                self.assertEqual(self.remote_main(), self.base)

    def test_generation_drift_is_held_before_a_candidate_exists(self):
        bundle = self.prepare()
        for name, mutate in (
            ("package.json", lambda x: x["scripts"].update(test="untrusted")),
            ("bun.lock", lambda x: x["packages"]["bun-types"][2]["dependencies"].update(extra="*")),
            ("bun.lock", lambda x: x["packages"]["undici-types"].__setitem__(0, "undici-types@9.0.0")),
        ):
            path = bundle / name
            original = path.read_text()
            data = json.loads(original)
            mutate(data)
            path.write_text(json.dumps(data))
            with self.subTest(file=name):
                self.assertNotEqual(self.cli("stage", "--bundle", str(bundle)).returncode, 0)
                self.assertEqual(self.remote_main(), self.base)
            self.git("reset", "--hard", self.base)
            path.write_text(original)
        (bundle / "bun.nix").write_text("unreproducible Nix expression")
        self.assertNotEqual(self.cli("stage", "--bundle", str(bundle)).returncode, 0)
        self.assertEqual(self.git("rev-parse", "HEAD"), self.base)

    def test_major_range_prerelease_and_downgrade_are_not_types_admission(self):
        for version in ("1.3.12", "1.2.99", "2.0.0", "1.3.14-beta.1", "^1.3.14"):
            self.git("checkout", "--detach", self.state["pr"]["head"]["sha"])
            manifest = json.loads((self.repo / PACKAGE / "package.json").read_text())
            manifest["devDependencies"]["@types/bun"] = version
            self.write(PACKAGE + "package.json", json.dumps(manifest))
            self.git("commit", "--quiet", "--allow-empty", "-am", "invalid proposal")
            self.state["pr"]["head"]["sha"] = self.git("rev-parse", "HEAD")
            self.git("push", "origin", "HEAD:refs/heads/renovate/callstack-types-patches")
            self.git("checkout", "--detach", self.base)
            self.save()
            with self.subTest(version=version):
                result = self.cli("select")
                self.assertNotEqual(result.returncode, 0)
                self.assertRegex(result.stderr, "Not an allowed|Versions must")
                self.assertEqual(self.remote_main(), self.base)

    def test_scheduled_minor_reuses_existing_undici_without_other_lock_drift(self):
        self.git("checkout", "--detach", self.state["pr"]["head"]["sha"])
        manifest = json.loads((self.repo / PACKAGE / "package.json").read_text())
        manifest["devDependencies"]["@types/bun"] = "1.4.4"
        self.write(PACKAGE + "package.json", json.dumps(manifest))
        self.git("commit", "--quiet", "-am", "minor proposal")
        self.state["pr"]["head"]["sha"] = self.git("rev-parse", "HEAD")
        self.git("push", "origin", "HEAD:refs/heads/renovate/callstack-types-patches")
        self.git("checkout", "--detach", self.base)
        self.save()
        sha = self.candidate()
        result = self.landing()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.remote_main(), sha)
        lock = json.loads((self.repo / PACKAGE / "bun.lock").read_text())
        self.assertEqual(lock["packages"]["undici-types"], self.lock["packages"]["undici-types"])
        self.assertEqual(lock["packages"]["bun-types"][2]["dependencies"]["undici-types"], "*")

    def test_lint_patch_lands_only_after_exact_ci_and_cannot_bypass_a_hold(self):
        self.lint_proposal()
        self.state["pr"]["labels"].append({"name": "hold"})
        manifest = json.loads((self.repo / PACKAGE / "package.json").read_text())
        manifest["description"] = "Updated on main after the proposal opened"
        self.write(PACKAGE + "package.json", json.dumps(manifest))
        self.git("commit", "--quiet", "-am", "update package description on main")
        self.git("push", "origin", "HEAD:refs/heads/main")
        self.base = self.git("rev-parse", "HEAD")
        self.state["origin"]["head_sha"] = self.base
        self.save()
        sha = self.candidate()
        record = self.state["record"]
        self.assertEqual((record["dependency"], record["pr"]), (LINT, 302))
        self.assertEqual(self.remote_main(), self.base)
        self.state["run"]["conclusion"] = "failure"
        self.assertNotEqual(self.landing().returncode, 0)
        self.state["run"]["conclusion"] = "success"
        self.state["lint_pr"]["labels"].append({"name": "hold"})
        self.assertNotEqual(self.landing().returncode, 0)
        self.state["lint_pr"]["labels"].pop()
        self.assertEqual(self.remote_main(), self.base)
        landed = self.landing()
        self.assertEqual(landed.returncode, 0, landed.stderr)
        self.assertEqual(self.remote_main(), sha)
        after = json.loads((self.repo / PACKAGE / "package.json").read_text())
        self.assertEqual(after["description"], manifest["description"])
        lock = json.loads((self.repo / PACKAGE / "bun.lock").read_text())
        for name in (*LINT_BINARIES, LINT):
            self.assertEqual(lock["packages"][name][0], f"{name}@7.0.2002")
        self.assertEqual(lock["packages"]["@types/bun"], self.lock["packages"]["@types/bun"])

    def test_lint_lane_holds_nonpatch_existing_or_young_proposals(self):
        self.state["prs"] = []
        for version in ("7.0.2000", "7.1.0", "8.0.0", "7.0.2002-beta.1"):
            with self.subTest(version=version):
                self.lint_proposal(version)
                self.assertNotEqual(self.cli("select").returncode, 0)
        self.lint_proposal()
        self.state["registry_times"] = {"@oxlint-tsgolint%2Flinux-x64": "2099-01-01T00:00:00Z"}
        self.save()
        self.assertIn("linux-x64 has not passed", self.cli("select").stderr)
        self.state["registry_times"] = {}
        self.state["lint_pr"]["created_at"] = "2023-12-31T23:59:59Z"
        self.save()
        self.assertNotEqual(self.cli("select").returncode, 0)
        self.assertEqual(self.remote_main(), self.base)

    def test_lint_lane_holds_unrelated_lock_changes_and_unexpected_platform_updates(self):
        self.state["prs"] = []
        self.lint_proposal()
        bundle = self.prepare()
        path = bundle / "bun.lock"
        original = path.read_text()
        for name, index, value in (
            ("undici-types", 0, "undici-types@9.0.0"),
            ("@oxlint-tsgolint/linux-x64", 1, "https://example.invalid/lint.tgz"),
            ("@oxlint-tsgolint/darwin-arm64", 2, {"os": "linux", "cpu": "arm64"}),
            ("oxlint-tsgolint", 2, {"optionalDependencies": {"other": "*"}}),
        ):
            with self.subTest(package=name, field=index):
                data = json.loads(original)
                data["packages"][name][index] = value
                path.write_text(json.dumps(data))
                self.assertNotEqual(self.cli("stage", "--bundle", str(bundle)).returncode, 0)
                self.assertEqual(self.remote_main(), self.base)
                self.git("reset", "--hard", self.base)

    def test_manual_minor_lands_only_with_dispatch_provenance_and_no_proposal(self):
        self.state["prs"] = []
        self.state["origin"]["event"] = "workflow_dispatch"
        self.env.update(GITHUB_EVENT_NAME="workflow_dispatch", GITHUB_REF="refs/heads/main",
                        TYPES_VERSION="1.4.0")
        self.save()
        sha = self.candidate("1.4.0")
        self.assertEqual(self.remote_main(), self.base)
        self.state["origin"]["event"] = "workflow_run"
        self.assertNotEqual(self.landing().returncode, 0)
        self.state["origin"]["event"] = "workflow_dispatch"
        self.state["prs"] = [self.state["pr"]]
        self.assertNotEqual(self.landing().returncode, 0)
        self.assertEqual(self.remote_main(), self.base)
        self.state["prs"] = []
        result = self.landing()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.remote_main(), sha)
        manifest = json.loads((self.repo / PACKAGE / "package.json").read_text())
        self.assertEqual(manifest["devDependencies"]["@types/bun"], "1.4.0")

    def test_manual_selection_cannot_bypass_dispatch_input_or_holds(self):
        self.assertNotEqual(self.cli("select", "--version", "1.4.0").returncode, 0)
        self.state["prs"] = []
        self.save()
        for version in ("1.3.13", "1.2.99", "2.0.0", "1.4.0-beta.1", "^1.4.0"):
            self.assertNotEqual(self.cli("select", "--version", version).returncode, 0)
        self.state["released"] = "2099-01-01T00:00:00Z"
        self.save()
        self.assertNotEqual(self.cli("select", "--version", "1.4.0").returncode, 0)
        self.state["released"] = "2024-01-01T00:00:00Z"
        self.save()
        bundle = self.prepare("1.4.0")
        trusted = self.env | {"GITHUB_EVENT_NAME": "workflow_dispatch", "GITHUB_REF": "refs/heads/main",
                              "TYPES_VERSION": "1.4.0"}
        for env in ({"GITHUB_EVENT_NAME": "workflow_run"}, {"GITHUB_REF": "refs/heads/untrusted"},
                    {"TYPES_VERSION": "1.4.4"}):
            self.env = trusted | env
            result = self.cli("stage", "--bundle", str(bundle))
            self.assertNotEqual(result.returncode, 0, result.stderr)
            self.assertEqual(self.git("rev-parse", "HEAD"), self.base)

    def test_failed_stale_wrong_provider_or_forged_provenance_never_lands(self):
        self.candidate()
        original = copy.deepcopy(self.state)
        for case in ("failed", "missing", "provider", "rerun", "record", "publisher", "hold"):
            self.state = copy.deepcopy(original)
            if case == "failed": self.state["run"]["conclusion"] = "failure"
            if case == "missing": self.state["jobs"] = self.state["jobs"][:1]
            if case == "provider": self.state["checks"][0]["app"]["id"] = 999
            if case == "rerun": self.state["rerun"] = True
            if case == "record": self.state["record"]["sha"] = self.base
            if case == "publisher": self.state["origin"]["event"] = "pull_request"
            if case == "hold": self.state["pr"]["labels"].append({"name":"hold"})
            with self.subTest(case=case):
                self.assertNotEqual(self.landing().returncode, 0)
                self.assertEqual(self.remote_main(), self.base)
        self.state = copy.deepcopy(original)
        self.git("checkout", "--detach", self.base)
        self.write("other", "another owner's work")
        self.git("add", "other")
        self.git("commit", "--quiet", "-m", "main moved")
        other = self.git("rev-parse", "HEAD")
        self.git("push", "origin", "HEAD:refs/heads/main")
        self.git("checkout", "--detach", self.base)
        self.assertNotEqual(self.landing().returncode, 0)
        self.assertEqual(self.remote_main(), other)


if __name__ == "__main__":
    unittest.main()
