#!/usr/bin/env python3
"""Admit allowlisted callstack development updates after exact-candidate CI.

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
from urllib.parse import quote

import candidate_ci as ci

PACKAGE = Path("packages/callstack-diff")
FILES = {"package.json", "bun.lock", "bun.nix"}
BUN_TYPES = "@types/bun"
TSGOLINT = "oxlint-tsgolint"
LANES = {
    BUN_TYPES: ("callstack-types-patches", "renovate-types-pilot"),
    TSGOLINT: ("callstack-tsgolint-patches", "renovate-lint-pilot"),
}
TSGOLINT_BINARIES = {
    f"@oxlint-tsgolint/{os_name}-{cpu}"
    for os_name in ("darwin", "linux", "win32") for cpu in ("arm64", "x64")
}
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


def manifest_version(before, after, dependency):
    if dependency not in LANES:
        raise ValueError("Dependency is not allowlisted for admission")
    old = before["devDependencies"][dependency]
    new = after["devDependencies"][dependency]
    versions = [re.fullmatch(VERSION, v) for v in (old, new)]
    if not all(versions):
        raise ValueError("Versions must be exact stable versions")
    a, b = [tuple(map(int, match.groups())) for match in versions]
    expected = copy.deepcopy(before)
    expected["devDependencies"][dependency] = new
    components = 1 if dependency == BUN_TYPES else 2
    if a[:components] != b[:components] or b <= a or expected != after:
        raise ValueError(f"Not an allowed {dependency} update")
    return new


def updated_manifest(before, dependency, version):
    after = copy.deepcopy(before)
    after["devDependencies"][dependency] = version
    manifest_version(before, after, dependency)
    return after


def replace_lock_entry(expected, after, name, metadata, version):
    entry = after["packages"][name]
    if (len(entry) != 4 or entry[:3] != [f"{name}@{version}", "", metadata]
            or not re.fullmatch(r"sha512-[A-Za-z0-9+/]{86}==", entry[3])):
        raise ValueError(f"Unexpected dependency metadata or registry for {name}")
    expected["packages"][name] = entry


def validate_lock(before, after, version, dependency):
    expected = copy.deepcopy(before)
    expected["workspaces"][""]["devDependencies"][dependency] = version
    if dependency == BUN_TYPES:
        for name in (BUN_TYPES, "bun-types"):
            metadata = copy.deepcopy(before["packages"][name][2])
            if name == BUN_TYPES:
                metadata["dependencies"]["bun-types"] = version
            elif ("undici-types" in before["packages"]
                  and after["packages"][name][2] == metadata | {
                      "dependencies": metadata["dependencies"] | {"undici-types": "*"},
                  }):
                # Bun 1.4 types also reference the already-pinned undici types.
                metadata = after["packages"][name][2]
            replace_lock_entry(expected, after, name, metadata, version)
    elif dependency == TSGOLINT:
        metadata = copy.deepcopy(before["packages"][TSGOLINT][2])
        if set(metadata["optionalDependencies"]) != TSGOLINT_BINARIES:
            raise ValueError("Unexpected platform packages for oxlint-tsgolint")
        metadata["optionalDependencies"] = dict.fromkeys(TSGOLINT_BINARIES, version)
        replace_lock_entry(expected, after, TSGOLINT, metadata, version)
        for name in sorted(TSGOLINT_BINARIES):
            replace_lock_entry(expected, after, name, before["packages"][name][2], version)
    else:
        raise ValueError("Dependency is not allowlisted for admission")
    if expected != after:
        raise ValueError(f"Unrelated lock drift is held for {dependency}")


def read_at(ref, name):
    return ci.git("show", f"{ref}:{PACKAGE / name}")


def validate_tree(base, bun, dependency):
    changes = ci.git("diff", "--name-only", base).splitlines()
    if not changes or not set(changes) <= {str(PACKAGE / f) for f in FILES}:
        raise ValueError("Candidate changes files outside the callstack dependency lane")
    for name in FILES:
        path = PACKAGE / name
        if path.is_symlink() or not path.is_file():
            raise ValueError("Candidate dependencies must be regular files")
        mode = ci.git("ls-files", "--stage", str(path)).split()[0]
        if mode != "100644" or path.stat().st_mode & 0o111:
            raise ValueError("Executable dependency files are not allowed")
    version = manifest_version(json.loads(read_at(base, "package.json")),
                               json.loads((PACKAGE / "package.json").read_text()), dependency)
    validate_lock(lock_data(read_at(base, "bun.lock"), bun),
                  lock_data((PACKAGE / "bun.lock").read_text(), bun), version, dependency)
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


def proposal(number, dependency):
    pr = ci.github(f"pulls/{number}")
    slug, label = LANES[dependency]
    if dependency == BUN_TYPES:
        introduced = ci.git("log", "--diff-filter=A", "--format=%cI", "--", WORKFLOW)
    else:
        introduced = ci.git("log", "-1", "--format=%cI", "-S", f'"groupSlug": "{slug}"',
                            "--", "renovate.json")
    if (not introduced or datetime.fromisoformat(pr["created_at"])
            <= datetime.fromisoformat(introduced.splitlines()[-1])
            or pr["state"] != "open" or pr["draft"] or pr.get("auto_merge")
            or pr["base"]["ref"] != "main"
            or pr["head"]["ref"] != f"renovate/{slug}"
            or pr["head"]["repo"]["full_name"] != ci.REPOSITORY
            or {entry["name"] for entry in pr["labels"]} != {"dependencies", "javascript", label}):
        raise ValueError(f"Only new, unheld, dedicated {dependency} proposals are eligible")
    pages = ci.github(f"pulls/{number}/files?per_page=100", paginate=True)
    paths = {item["filename"] for page in pages for item in page}
    if (str(PACKAGE / "package.json") not in paths
            or not paths <= {str(PACKAGE / f) for f in FILES}):
        raise ValueError("Proposal contains files outside the callstack dependency lane")
    source = pr["head"]["sha"]
    status = ci.github(f"commits/{source}/status")
    if any(s["context"] == "renovate/artifacts" and s["state"] != "success"
           for s in status["statuses"]):
        raise ValueError("Renovate artifact failure is held")
    ci.git("fetch", "--no-tags", "origin", source)
    merge_base = ci.git("merge-base", "HEAD", source)
    version = manifest_version(json.loads(read_at(merge_base, "package.json")),
                               json.loads(read_at(source, "package.json")), dependency)
    updated_manifest(json.loads(read_at("HEAD", "package.json")), dependency, version)
    release_age(dependency, version)
    return source, version


def release_age(dependency, version):
    companions = ["bun-types"] if dependency == BUN_TYPES else sorted(TSGOLINT_BINARIES)
    for name in [dependency, *companions]:
        metadata = json.loads(run("curl", "--fail", "--silent", "--show-error",
                                  "--max-time", "30", f"https://registry.npmjs.org/{quote(name, safe='@')}",
                                  env=isolated_env()))
        released = datetime.fromisoformat(metadata["time"][version])
        if datetime.now(timezone.utc) - released < timedelta(days=3):
            raise ValueError(f"{name} has not passed the three-day stability window")


def open_proposals(dependency):
    slug, _ = LANES[dependency]
    return ci.github(f"pulls?state=open&head=edmundmiller:renovate/{slug}&per_page=100")


def manual_release(version):
    if open_proposals(BUN_TYPES):
        raise ValueError("Manual admission must not bypass an existing types proposal or hold")
    release_age(BUN_TYPES, version)


def select_proposal(before):
    held = []
    for dependency in LANES:
        prs = open_proposals(dependency)
        if not prs:
            continue
        try:
            if len(prs) != 1:
                raise ValueError(f"Ambiguous {dependency} proposal")
            number = prs[0]["number"]
            source = prs[0]["head"]["sha"]
            ci.git("fetch", "--no-tags", "origin", source)
            after = json.loads(read_at(source, "package.json"))
            if before["devDependencies"][dependency] == after["devDependencies"][dependency]:
                # A retained proposal already applied to main is a no-op.
                continue
            source, version = proposal(number, dependency)
            return dependency, number, source, version
        except ValueError as error:
            held.append(str(error))
    if held:
        raise ValueError("; ".join(held))
    return None


def select(version=None):
    base = ci.git("rev-parse", "HEAD")
    before = json.loads(read_at(base, "package.json"))
    if version is None:
        selected = select_proposal(before)
        if selected is None:
            return {"selected": False}
        dependency, number, source, version = selected
    else:
        dependency, number, source = BUN_TYPES, None, base
        updated_manifest(before, dependency, version)
        manual_release(version)
    if ci.remote_sha("refs/heads/main") != base:
        raise ValueError("Main moved; wait for the next Renovate run")
    # A different outstanding candidate must finish before this lane starts.
    if ci.github(f"git/matching-refs/heads/candidate/{base}/"):
        raise ValueError("An outstanding candidate already owns this base")
    return {"selected": True, "base": base, "source": source,
            "pr": number, "version": version, "dependency": dependency}


def prepare(selection, output):
    if ci.git("status", "--porcelain") or ci.git("rev-parse", "HEAD") != selection["base"]:
        raise ValueError("Preparation requires the exact clean selected base")
    binary = tools()
    manifest = PACKAGE / "package.json"
    before = json.loads(manifest.read_text())
    dependency = selection["dependency"]
    after = updated_manifest(before, dependency, selection["version"])
    manifest.write_text(json.dumps(after, indent=2) + "\n")
    subprocess.run([str(binary / "bun"), "install", "--lockfile-only", "--ignore-scripts"],
                   cwd=PACKAGE, check=True, env=isolated_env(), stdout=sys.stderr)
    validate_tree(selection["base"], binary / "bun", dependency)
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
    if set(record) != {"selected", "base", "source", "pr", "version", "dependency"} or record["selected"] is not True:
        raise ValueError("Invalid proposal record")
    dependency = record["dependency"]
    if dependency not in LANES:
        raise ValueError("Dependency is not allowlisted for admission")
    if (ci.git("status", "--porcelain") or ci.git("rev-parse", "HEAD") != record["base"]
            or ci.remote_sha("refs/heads/main") != record["base"]):
        raise ValueError("Main or proposal moved, or proposal is held")
    if record["pr"] is None:
        if (dependency != BUN_TYPES or os.environ.get("GITHUB_EVENT_NAME") != "workflow_dispatch"
                or os.environ.get("GITHUB_REF") != "refs/heads/main"
                or os.environ.get("TYPES_VERSION") != record["version"]
                or record["source"] != record["base"]):
            raise ValueError("Manual selection must bind the trusted main dispatch and version")
        manual_release(record["version"])
    elif proposal(record["pr"], dependency) != (record["source"], record["version"]):
        raise ValueError("Proposal moved, is held or differs from the artifact")
    for name in FILES:
        (PACKAGE / name).write_bytes((bundle / name).read_bytes())
    binary = tools()
    if validate_tree(record["base"], binary / "bun", dependency) != record["version"]:
        raise ValueError("Generated version does not match the proposal")
    generated_matches(binary)
    record["run"] = int(os.environ["GITHUB_RUN_ID"])
    record["attempt"] = int(os.environ["GITHUB_RUN_ATTEMPT"])
    ci.git("add", "--", *[str(PACKAGE / f) for f in sorted(FILES)])
    source = (f"Source-PR: https://github.com/{ci.REPOSITORY}/pull/{record['pr']}"
              if record["pr"] is not None else "Source: isolated manual types dispatch")
    ci.git("-c", "user.name=Renovate candidate admission", "-c",
           "user.email=renovate@users.noreply.github.com", "commit", "--no-gpg-sign", "-m",
           f"chore(callstack-diff): update {dependency} to {record['version']}\n\n"
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
    # Publisher records created before the second lane only describe Bun types.
    dependency = record.get("dependency", BUN_TYPES)
    if dependency not in LANES:
        raise ValueError("Dependency is not allowlisted for admission")
    if record["pr"] is None:
        if dependency != BUN_TYPES or origin["event"] != "workflow_dispatch" or record["source"] != base:
            raise ValueError("Manual candidate requires the trusted main dispatch")
        manual_release(record["version"])
    elif (origin["event"] != "workflow_run"
          or proposal(record["pr"], dependency) != (record["source"], record["version"])):
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
    if validate_tree(base, tools() / "bun", dependency) != record["version"]:
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
        print(f"Renovate admission held: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
