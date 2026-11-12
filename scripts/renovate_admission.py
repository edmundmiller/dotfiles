#!/usr/bin/env python3
"""The callstack types-only pilot. Preparation never has a write credential.

Run only from trusted main. Existing PRs, merge APIs and deployment are excluded.
"""

import argparse
import copy
from datetime import datetime, timedelta, timezone
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import tempfile

import candidate_ci as ci

PACKAGE = Path("packages/callstack-diff")
FILES = {"package.json", "bun.lock", "bun.nix"}
BRANCH = "renovate/callstack-types-patches"
LABELS = {"dependencies", "javascript", "renovate-types-pilot"}
WORKFLOW = ".github/workflows/renovate-admission.yml"
VERSION = r"(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)"


def run(*command, **kwargs):
    return subprocess.check_output(command, text=True, **kwargs).strip()


def isolated_env():
    # Neither registry tooling nor tests inherit repository write/fetch secrets.
    return {key: value for key, value in os.environ.items() if key in {
        "PATH", "HOME", "TMPDIR", "NIX_SSL_CERT_FILE", "SSL_CERT_FILE",
    }}


def tools():
    expression = '''let
      f = builtins.getFlake (toString ./.);
      system = builtins.currentSystem;
      p = import f.inputs.nixpkgs { inherit system; };
    in p.buildEnv { name = "renovate-types-tools";
      paths = [ p.bun p.deadnix p.nixfmt f.inputs.bun2nix.packages.${system}.bun2nix ]; }
    '''
    return Path(run("nix", "--accept-flake-config", "build", "--impure",
                    "--no-link", "--no-write-lock-file", "--print-out-paths",
                    "--expr", expression, env=isolated_env())) / "bin"


def lock_data(text, bun):
    return json.loads(run(str(bun), "-e",
                          "console.log(JSON.stringify(Bun.JSONC.parse(await Bun.stdin.text())))",
                          input=text, env=isolated_env()))


def manifest_version(before, after):
    old = before["devDependencies"]["@types/bun"]
    new = after["devDependencies"]["@types/bun"]
    versions = [re.fullmatch(VERSION, v) for v in (old, new)]
    if not all(versions):
        raise ValueError("Types versions must be exact stable versions")
    a, b = [tuple(map(int, match.groups())) for match in versions]
    expected = copy.deepcopy(before)
    expected["devDependencies"]["@types/bun"] = new
    if a[0] != b[0] or b <= a or expected != after:
        raise ValueError("Only an increasing @types/bun minor or patch is allowed")
    return new


def validate_lock(before, after, version):
    expected = copy.deepcopy(before)
    expected["workspaces"][""]["devDependencies"]["@types/bun"] = version
    for name in ("@types/bun", "bun-types"):
        entry = after["packages"][name]
        metadata = copy.deepcopy(before["packages"][name][2])
        if name == "@types/bun":
            metadata["dependencies"]["bun-types"] = version
        elif ("undici-types" in before["packages"]
              and entry[2] == metadata | {"dependencies": metadata["dependencies"] | {"undici-types": "*"}}):
            # Bun 1.4 types also reference the already-pinned undici types.
            metadata = entry[2]
        if (len(entry) != 4 or entry[:3] != [f"{name}@{version}", "", metadata]
                or not re.fullmatch(r"sha512-[A-Za-z0-9+/]{86}==", entry[3])):
            raise ValueError("Unexpected types dependency metadata or registry")
        expected["packages"][name] = entry
    if expected != after:
        raise ValueError("Lock drift outside @types/bun and bun-types is held")


def read_at(ref, name):
    return ci.git("show", f"{ref}:{PACKAGE / name}")


def validate_tree(base, bun):
    changes = ci.git("diff", "--name-only", base).splitlines()
    if not changes or not set(changes) <= {str(PACKAGE / f) for f in FILES}:
        raise ValueError("Candidate changes files outside the types lane")
    for name in FILES:
        path = PACKAGE / name
        if path.is_symlink() or not path.is_file():
            raise ValueError("Candidate dependencies must be regular files")
        mode = ci.git("ls-files", "--stage", str(path)).split()[0]
        if mode != "100644" or path.stat().st_mode & 0o111:
            raise ValueError("Executable dependency files are not allowed")
    version = manifest_version(json.loads(read_at(base, "package.json")),
                               json.loads((PACKAGE / "package.json").read_text()))
    validate_lock(lock_data(read_at(base, "bun.lock"), bun),
                  lock_data((PACKAGE / "bun.lock").read_text(), bun), version)
    return version


def generate(binary, target):
    subprocess.run([str(binary / "bun2nix"), "-l", str(PACKAGE / "bun.lock"), "-o", str(target)],
                   check=True, env=isolated_env(), stdout=sys.stderr)
    # Match the repository's generated-Nix normalization, not raw generator bytes.
    for command in ([str(binary / "deadnix"), "--edit", str(target)],
                    [str(binary / "nixfmt"), str(target)]):
        subprocess.run(command, check=True, env=isolated_env(), stdout=sys.stderr)


def generated_matches(binary):
    with tempfile.TemporaryDirectory(prefix="types-generation-") as temp:
        target = Path(temp) / "bun.nix"
        generate(binary, target)
        if target.read_bytes() != (PACKAGE / "bun.nix").read_bytes():
            raise ValueError("bun.nix does not reproduce from the pinned generator")


def proposal(number):
    pr = ci.github(f"pulls/{number}")
    introduced = ci.git("log", "--diff-filter=A", "--format=%cI", "--", WORKFLOW)
    if (not introduced or datetime.fromisoformat(pr["created_at"])
            <= datetime.fromisoformat(introduced.splitlines()[-1])
            or pr["state"] != "open" or pr["draft"] or pr.get("auto_merge")
            or pr["head"]["ref"] != BRANCH
            or pr["head"]["repo"]["full_name"] != ci.REPOSITORY
            or {label["name"] for label in pr["labels"]} != LABELS):
        raise ValueError("Only new, unheld, dedicated types proposals are eligible")
    pages = ci.github(f"pulls/{number}/files?per_page=100", paginate=True)
    paths = {item["filename"] for page in pages for item in page}
    if (str(PACKAGE / "package.json") not in paths
            or not paths <= {str(PACKAGE / f) for f in FILES}):
        raise ValueError("Proposal contains files outside the types lane")
    source = pr["head"]["sha"]
    status = ci.github(f"commits/{source}/status")
    if any(s["context"] == "renovate/artifacts" and s["state"] != "success"
           for s in status["statuses"]):
        raise ValueError("Renovate artifact failure is held")
    ci.git("fetch", "--no-tags", "origin", source)
    version = manifest_version(json.loads(read_at("HEAD", "package.json")),
                               json.loads(read_at(source, "package.json")))
    release_age(version)
    return source


def release_age(version):
    for name in ("@types%2fbun", "bun-types"):
        metadata = json.loads(run("curl", "--fail", "--silent", "--show-error",
                                  "--max-time", "30", f"https://registry.npmjs.org/{name}",
                                  env=isolated_env()))
        released = datetime.fromisoformat(metadata["time"][version])
        if datetime.now(timezone.utc) - released < timedelta(days=3):
            raise ValueError("Types release has not passed the three-day stability window")


def manual_release(version):
    if ci.github(f"pulls?state=open&head=edmundmiller:{BRANCH}&per_page=100"):
        raise ValueError("Manual admission must not bypass an existing types proposal or hold")
    release_age(version)


def select(version=None):
    base = ci.git("rev-parse", "HEAD")
    if version is None:
        prs = ci.github(f"pulls?state=open&head=edmundmiller:{BRANCH}&per_page=100")
        if not prs:
            return {"selected": False}
        if len(prs) != 1:
            raise ValueError("Ambiguous types proposal")
        number = prs[0]["number"]
        source = prs[0]["head"]["sha"]
        ci.git("fetch", "--no-tags", "origin", source)
        if json.loads(read_at(base, "package.json")) == json.loads(read_at(source, "package.json")):
            # A retained proposal already applied to main is a no-op, not a daily failure.
            return {"selected": False}
        source = proposal(number)
        version = manifest_version(json.loads(read_at(base, "package.json")),
                                   json.loads(read_at(source, "package.json")))
    else:
        number, source = None, base
        before = json.loads(read_at(base, "package.json"))
        after = copy.deepcopy(before)
        after["devDependencies"]["@types/bun"] = version
        manifest_version(before, after)
        manual_release(version)
    if ci.remote_sha("refs/heads/main") != base:
        raise ValueError("Main moved; wait for the next Renovate run")
    # A different outstanding candidate must finish before this lane starts.
    if ci.github(f"git/matching-refs/heads/candidate/{base}/"):
        raise ValueError("An outstanding candidate already owns this base")
    return {"selected": True, "base": base, "source": source,
            "pr": number, "version": version}


def prepare(selection, output):
    if ci.git("status", "--porcelain") or ci.git("rev-parse", "HEAD") != selection["base"]:
        raise ValueError("Preparation requires the exact clean selected base")
    binary = tools()
    manifest = PACKAGE / "package.json"
    before = json.loads(manifest.read_text())
    after = copy.deepcopy(before)
    after["devDependencies"]["@types/bun"] = selection["version"]
    manifest_version(before, after)
    manifest.write_text(json.dumps(after, indent=2) + "\n")
    subprocess.run([str(binary / "bun"), "install", "--lockfile-only", "--ignore-scripts"],
                   cwd=PACKAGE, check=True, env=isolated_env(), stdout=sys.stderr)
    validate_tree(selection["base"], binary / "bun")
    generate(binary, PACKAGE / "bun.nix")
    output.mkdir(parents=True)
    for name in FILES:
        (output / name).write_bytes((PACKAGE / name).read_bytes())
    (output / "selection.json").write_text(json.dumps(selection))


def stage(bundle):
    if {p.name for p in bundle.iterdir()} != FILES | {"selection.json"}:
        raise ValueError("Unexpected generation artifact contents")
    if any(not p.is_file() or p.is_symlink() for p in bundle.iterdir()):
        raise ValueError("Generation artifact must contain only regular files")
    record = json.loads((bundle / "selection.json").read_text())
    if set(record) != {"selected", "base", "source", "pr", "version"} or not record["selected"]:
        raise ValueError("Invalid proposal record")
    if (ci.git("status", "--porcelain") or ci.git("rev-parse", "HEAD") != record["base"]
            or ci.remote_sha("refs/heads/main") != record["base"]):
        raise ValueError("Main or proposal moved, or proposal is held")
    if record["pr"] is None:
        if (os.environ.get("GITHUB_EVENT_NAME") != "workflow_dispatch"
                or os.environ.get("GITHUB_REF") != "refs/heads/main"
                or os.environ.get("TYPES_VERSION") != record["version"]
                or record["source"] != record["base"]):
            raise ValueError("Manual selection must bind the trusted main dispatch and version")
        manual_release(record["version"])
    else:
        if proposal(record["pr"]) != record["source"]:
            raise ValueError("Proposal moved or is held")
        proposed = manifest_version(json.loads(read_at(record["base"], "package.json")),
                                    json.loads(read_at(record["source"], "package.json")))
        if proposed != record["version"]:
            raise ValueError("Artifact version differs from the selected proposal")
    for name in FILES:
        (PACKAGE / name).write_bytes((bundle / name).read_bytes())
    binary = tools()
    if validate_tree(record["base"], binary / "bun") != record["version"]:
        raise ValueError("Generated version does not match the proposal")
    generated_matches(binary)
    record["run"] = int(os.environ["GITHUB_RUN_ID"])
    record["attempt"] = int(os.environ["GITHUB_RUN_ATTEMPT"])
    ci.git("add", "--", *[str(PACKAGE / f) for f in sorted(FILES)])
    source = (f"Source-PR: https://github.com/{ci.REPOSITORY}/pull/{record['pr']}"
              if record["pr"] is not None else "Source: isolated manual types dispatch")
    ci.git("-c", "user.name=Renovate types admission", "-c",
           "user.email=renovate@users.noreply.github.com", "commit", "--no-gpg-sign", "-m",
           f"chore(callstack-diff): update Bun types to {record['version']}\n\n"
           f"Renovate-Types-Run: {record['run']}/{record['attempt']}\n"
           f"{source}")
    record["sha"] = ci.git("rev-parse", "HEAD")
    return record


def land(event):
    current = event["workflow_run"]
    branch = current["head_branch"]
    match = re.fullmatch(f"candidate/({ci.SHA})/({ci.SHA})", branch)
    if not match or current["path"] != ".github/workflows/ci.yml":
        return {"selected": False}
    base, sha = match.groups()
    if current["head_sha"] != sha:
        raise ValueError("Event does not identify the candidate")
    ci.git("fetch", "--no-tags", "origin", sha)
    message = ci.git("show", "-s", "--format=%B", sha)
    provenance = re.findall(r"^Renovate-Types-Run: ([1-9][0-9]*)/([1-9][0-9]*)$", message, re.M)
    if not provenance:
        return {"selected": False}
    if len(provenance) != 1 or ci.git("rev-parse", f"{sha}^@") != base:
        raise ValueError("Invalid types candidate ancestry or provenance")
    run_id, attempt = map(int, provenance[0])
    origin = ci.github(f"actions/runs/{run_id}")
    if (origin["path"] != WORKFLOW or origin["event"] not in {"workflow_run", "workflow_dispatch"}
            or origin["head_sha"] != base or origin["head_branch"] != "main"
            or origin["run_attempt"] != attempt or origin["status"] != "completed"
            or origin["conclusion"] != "success"):
        raise ValueError("Candidate publisher is not the successful trusted workflow attempt")
    with tempfile.TemporaryDirectory(prefix="types-provenance-") as temp:
        subprocess.run(["gh", "run", "download", str(run_id), "--repo", ci.REPOSITORY,
                        "--name", f"types-candidate-{attempt}", "--dir", temp], check=True,
                       env=os.environ | {"GH_HOST": "github.com"})
        files = list(Path(temp).iterdir())
        if len(files) != 1 or files[0].name != "record.json" or files[0].is_symlink():
            raise ValueError("Invalid candidate provenance artifact")
        record = json.loads(files[0].read_text())
    if (record["base"] != base or record["sha"] != sha or record["run"] != run_id
            or record["attempt"] != attempt):
        raise ValueError("Publisher record does not bind this candidate and current proposal")
    if record["pr"] is None:
        if origin["event"] != "workflow_dispatch" or record["source"] != base:
            raise ValueError("Manual candidate requires the trusted main dispatch")
        manual_release(record["version"])
    elif origin["event"] != "workflow_run" or proposal(record["pr"]) != record["source"]:
        raise ValueError("Scheduled candidate requires its current unheld proposal")
    if ci.remote_sha("refs/heads/main") != base:
        raise ValueError("Main moved; regenerate on the next Renovate run")
    ci.passing_candidate(base, sha)
    pages = ci.github(f"commits/{sha}/check-runs?per_page=100", paginate=True)
    for name in ci.REQUIRED:
        if not any(check["name"] == name and check["app"]["id"] == 15368
                   and check["conclusion"] == "success"
                   for page in pages for check in page["check_runs"]):
            raise ValueError("Missing Actions-provider-bound candidate check")
    ci.git("checkout", "--detach", sha)
    if validate_tree(base, tools() / "bun") != record["version"]:
        raise ValueError("Candidate version differs from publisher record")
    return ci.publish("land", base, sha)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest="command", required=True)
    select_parser = commands.add_parser("select")
    select_parser.add_argument("--version", help="Select an exact types version without a PR")
    prepare_parser = commands.add_parser("prepare")
    prepare_parser.add_argument("--selection", type=Path, required=True)
    prepare_parser.add_argument("--output", type=Path, required=True)
    stage_parser = commands.add_parser("stage")
    stage_parser.add_argument("--bundle", type=Path, required=True)
    submit_parser = commands.add_parser("submit")
    submit_parser.add_argument("--record", type=Path, required=True)
    land_parser = commands.add_parser("land")
    land_parser.add_argument("--event", type=Path, required=True)
    commands.add_parser("check-generated")
    args = parser.parse_args()
    try:
        result = None
        if args.command == "select":
            result = select(args.version)
        elif args.command == "prepare":
            prepare(json.loads(args.selection.read_text()), args.output)
        elif args.command == "stage":
            result = stage(args.bundle)
        elif args.command == "submit":
            record = json.loads(args.record.read_text())
            if not ci.github("")["permissions"]["push"]:
                raise ValueError("Candidate credential lacks repository push access")
            result = ci.publish("submit", record["base"], record["sha"])
        elif args.command == "land":
            result = land(json.loads(args.event.read_text()))
        else:
            generated_matches(tools())
        if result is not None:
            print(json.dumps(result, sort_keys=True))
        return 0
    except (ValueError, KeyError, IndexError, TypeError, OSError, subprocess.SubprocessError) as error:
        print(f"Types admission held: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
