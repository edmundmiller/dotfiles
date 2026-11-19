#!/usr/bin/env python3
"""Hand authorized publication to GitHub; completion events advance it without an orb."""

import argparse
from datetime import datetime, timedelta, timezone
import fcntl
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile

import candidate_ci as ci
import nuc_shipping as nuc
import nuc_rollout as rollout

WORKFLOW = ".github/workflows/ship.yml"
ARTIFACT = "ship-request-v1"
SUCCESSOR = "ship-successor-v2"
OPTIONS = ("allow_clean_rebase", "deploy_rebased", "darwin", "services_vm")
MAX_REBASES = 3


def request_options(inputs):
    options = {key: inputs.get(key, "false") for key in OPTIONS}
    if any(value not in {"true", "false"} for value in options.values()):
        raise ValueError("Ship options must be explicit booleans")
    if options["allow_clean_rebase"] != "true" and any(
        options[key] == "true" for key in OPTIONS[1:]
    ):
        raise ValueError("Rebased deployment and hosted platform profiles require clean-rebase mode")
    if options["allow_clean_rebase"] == "true" and inputs["deploy"] == "true" and options["deploy_rebased"] != "true":
        raise ValueError("Clean-rebase deployment requires explicit --deploy-rebased authority")
    if options["deploy_rebased"] == "true" and inputs["deploy"] != "true":
        raise ValueError("Rebased deployment requires deployment authority")
    return options if options["allow_clean_rebase"] == "true" else {}


def continuous():
    return os.environ.get("NUC_ROLLOUT") == "continuous"


def api(endpoint, payload=None):
    if payload is None:
        return ci.github(endpoint)
    result = subprocess.check_output(
        ["gh", "api", "--hostname", "github.com", f"repos/{ci.REPOSITORY}/{endpoint}",
         "--method", "POST", "--input", "-"],
        input=json.dumps(payload), text=True, timeout=30,
    )
    return json.loads(result) if result.strip() else None


def request(args):
    path = args.receipt.resolve(strict=True)
    with path.with_suffix(path.suffix + ".shipping-lock").open("a") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        receipt = json.loads(path.read_text())
        if (receipt.get("schemaVersion") != 2 or receipt.get("status") != "active"
                or receipt.get("authority", {}).get("mode") not in {"full", "commit-push"}
                or (args.deploy and receipt["authority"]["mode"] != "full")
                or not args.authority.strip() or not args.thread.strip()):
            raise ValueError("An active receipt and explicit publication/deployment authority are required")
        ci.candidate_branch(args.base, args.sha)
        inputs = dict(base=args.base, sha=args.sha, deploy=str(args.deploy).lower(),
                      authority=args.authority, owner=args.thread)
        inputs.update(request_options(inputs | {
            key: str(getattr(args, key)).lower() for key in OPTIONS
        }))
        if receipt.get("nucShipping"):
            raise ValueError("This receipt already owns a direct NUC request; do not mix shipping routes")
        previous = receipt.get("shipRequest")
        if previous:
            if previous["inputs"] != inputs:
                raise ValueError("A different Ship request already owns this receipt")
            if previous["state"] == "dispatch_unknown":
                raise ValueError("Ship dispatch is uncertain; inspect Actions before any retry")
            return previous
        if not inputs.get("allow_clean_rebase") and api("git/ref/heads/main")["object"]["sha"] != args.base:
            raise ValueError("Main moved; reconcile and validate a new candidate")
        branch = ci.candidate_branch(args.base, args.sha)
        if api(f"git/ref/heads/{branch}")["object"]["sha"] != args.sha:
            raise ValueError("Submit the exact candidate before requesting Ship")
        claim = receipt["shipRequest"] = dict(
            inputs=inputs, state="dispatch_unknown",
            dispatchStartedAt=datetime.now(timezone.utc).isoformat(),
            nextAction="Find Ship SHA in GitHub Actions; never redispatch an uncertain request.",
        )
        nuc.save_shipping_receipt(path, receipt)
        api("actions/workflows/ship.yml/dispatches", {"ref": "main", "inputs": inputs})
        claim["state"] = "accepted"
        nuc.save_shipping_receipt(path, receipt)
        return claim


def register(event):
    """Only an explicit main dispatch creates authority, never a CI event."""
    inputs = {key: event["inputs"][key] for key in ("base", "sha", "deploy", "authority", "owner")}
    options = request_options(event["inputs"])
    inputs.update(options)
    base, sha = inputs["base"], inputs["sha"]
    branch = ci.candidate_branch(base, sha)
    captured = os.environ["GITHUB_SHA"]
    if (event["ref"] != "refs/heads/main" or (not options and captured != base)
            or inputs["deploy"] not in {"true", "false"}
            or not inputs["authority"].strip() or not inputs["owner"].strip()):
        raise ValueError("Ship requires explicit authority on the exact main base")
    main = api("git/ref/heads/main")["object"]["sha"]
    if not options and main != base:
        raise ValueError("Main moved before Ship registration")
    if api(f"git/ref/heads/{branch}")["object"]["sha"] != sha:
        raise ValueError("Candidate ref differs from the authorized revision")
    ci.git("fetch", "--no-tags", "origin", sha)
    ci.git("merge-base", "--is-ancestor", base, sha)
    if continuous() and inputs["deploy"] == "false":
        # Standing rollout would otherwise activate this no-deploy task later.
        rollout.require_publication_only(base, sha)
    if options:
        ci.git("fetch", "--no-tags", "origin", main, captured)
        ci.git("merge-base", "--is-ancestor", base, captured)
        ci.git("merge-base", "--is-ancestor", captured, main)
        inputs.update(schemaVersion=2, registeredHead=captured,
                      createdAt=datetime.now(timezone.utc).isoformat())
    return inputs | {"run": int(os.environ["GITHUB_RUN_ID"]),
                     "attempt": int(os.environ["GITHUB_RUN_ATTEMPT"])}


def find_request(sha):
    # Requests expire after seven days; old intent must not activate on a much later rerun.
    since = (datetime.now(timezone.utc) - timedelta(days=7)).strftime("%Y-%m-%d")
    pages = ci.github(
        f"actions/workflows/ship.yml/runs?event=workflow_dispatch&branch=main&created=%3E%3D{since}&per_page=100",
        paginate=True,
    )
    runs = [run for page in pages for run in page["workflow_runs"]
            if run["display_title"] == f"Ship {sha}"]
    if not runs:
        return None
    run = max(runs, key=lambda item: item["id"])
    if (run["path"] != WORKFLOW or run["event"] != "workflow_dispatch"
            or run["head_branch"] != "main" or run["conclusion"] == "cancelled"
            or run["repository"]["full_name"] != ci.REPOSITORY
            or run["head_repository"]["full_name"] != ci.REPOSITORY):
        raise ValueError("Ship request is not a live trusted main dispatch")
    record = download_record(run, ARTIFACT)
    if record is None:
        return None
    options = request_options(record)
    captured = record["registeredHead"] if options else record["base"]
    if (record["run"] != run["id"] or record["attempt"] != run["run_attempt"]
            or captured != run["head_sha"] or record["sha"] != sha
            or record["deploy"] not in {"true", "false"}
            or not record["authority"].strip() or not record["owner"].strip()):
        raise ValueError("Ship authorization does not bind this exact revision and attempt")
    ci.candidate_branch(record["base"], sha)
    if options:
        if record["schemaVersion"] != 2 or datetime.now(timezone.utc) - datetime.fromisoformat(record["createdAt"]) > timedelta(days=7):
            raise ValueError("Rebase authorization is invalid or expired")
    return record


def download_record(run, prefix):
    name = f"{prefix}-{run['run_attempt']}"
    artifacts = api(f"actions/runs/{run['id']}/artifacts?per_page=100")["artifacts"]
    matches = [item for item in artifacts if item["name"] == name and not item["expired"]]
    if not matches:
        if run["status"] == "completed":
            raise ValueError("Completed Ship registration has no live authorization artifact")
        return None  # Registration may still be uploading; its own advance step closes the race.
    if len(matches) != 1 or matches[0]["size_in_bytes"] > 65536:
        raise ValueError("Invalid Ship authorization artifact")
    with tempfile.TemporaryDirectory(prefix="ship-request-") as directory:
        subprocess.run(
            ["gh", "run", "download", str(run["id"]), "--repo", ci.REPOSITORY,
             "--name", name, "--dir", directory], check=True, timeout=30,
            env=os.environ | {"GH_HOST": "github.com"},
        )
        files = list(Path(directory).iterdir())
        if len(files) != 1 or files[0].name != "request.json" or files[0].is_symlink():
            raise ValueError("Unexpected Ship artifact files")
        record = json.loads(files[0].read_text())
    return record


def tag_record(name):
    ref = f"refs/tags/{name}"
    matches = [item for item in api(f"git/matching-refs/tags/{name}") if item["ref"] == ref]
    if not matches:
        return None
    tag = api(f"git/tags/{matches[0]['object']['sha']}")
    record = json.loads(tag["message"])
    if tag["object"].get("type") != "commit" or tag["object"].get("sha") != record["sha"]:
        raise ValueError("Successor locator does not identify its candidate")
    return record


def next_name(root, sha):
    return f"ship-next/{root['run']}-{root['attempt']}/{sha}"


def lineage(root):
    """Refs locate records; only trusted Ship artifacts authorize successors."""
    generations = [root | {"generation": 0}]
    if root.get("allow_clean_rebase") != "true":
        return generations
    while locator := tag_record(next_name(root, generations[-1]["sha"])):
        previous = generations[-1]
        if previous["generation"] >= MAX_REBASES:
            raise ValueError("Too many successor generations")
        # A later producer retry must not replace this immutable attempt's evidence.
        run = api(f"actions/runs/{locator['run']}/attempts/{locator['attempt']}")
        if (run["id"] != locator["run"] or run["path"] != WORKFLOW or run["head_branch"] != "main"
                or run["event"] not in {"workflow_run", "workflow_dispatch"}
                or run["run_attempt"] != locator["attempt"] or run["conclusion"] == "cancelled"
                or run["repository"]["full_name"] != ci.REPOSITORY
                or run["head_repository"]["full_name"] != ci.REPOSITORY):
            raise ValueError("Successor was not produced by trusted main Ship")
        record = download_record(run, SUCCESSOR)
        if record is None or record != locator or any(record.get(key) != value for key, value in {
            "schemaVersion": 2, "rootSha": root["sha"], "rootRun": root["run"],
            "rootAttempt": root["attempt"], "previousSha": previous["sha"],
            "generation": previous["generation"] + 1,
        }.items()):
            raise ValueError("Successor artifact does not bind this request and generation")
        ci.candidate_branch(record["base"], record["sha"])
        if tag_record(f"ship-source/{record['sha']}") != record:
            raise ValueError("Successor reverse locator differs from its authorization")
        generations.append(record)
    return generations


def prepare_rebase(root, current, main, destination):
    if destination is None:
        raise ValueError("Clean rebase requires a successor artifact destination")
    if current["generation"] >= MAX_REBASES:
        raise ValueError("Clean rebase limit reached; reconcile manually")
    ci.require_origin()
    ci.git("fetch", "--no-tags", "origin", main, root["sha"], current["sha"])
    ci.git("merge-base", "--is-ancestor", current["base"], main)
    contains_candidate = subprocess.run(
        ["git", "merge-base", "--is-ancestor", current["sha"], main], check=False,
    )
    if contains_candidate.returncode != 1:
        raise ValueError("Candidate may already be published; inspect the original landing")
    if ci.git("rev-list", "--merges", f"{root['base']}..{root['sha']}"):
        raise ValueError("Automatic replay does not accept merge commits")
    count = ci.git("rev-list", "--count", f"{root['base']}..{root['sha']}")
    # Clone without repository config, hooks, filters, credentials or rerere state.
    # No candidate Python, shell, Nix or Git hooks execute in the privileged job.
    environment = {key: os.environ[key] for key in ("PATH", "TMPDIR", "LANG", "LC_ALL")
                   if key in os.environ}
    environment.update(GIT_CONFIG_GLOBAL="/dev/null", GIT_CONFIG_SYSTEM="/dev/null",
                       GIT_TERMINAL_PROMPT="0", GIT_EDITOR="false", GIT_SEQUENCE_EDITOR="false")
    with tempfile.TemporaryDirectory(prefix="ship-rebase-") as directory:
        def git(*args):
            return subprocess.check_output(
                ["git", "-c", "core.hooksPath=/dev/null", "-c", "commit.gpgsign=false",
                 "-c", "rerere.enabled=false", "-C", directory, *args],
                env=environment, text=True, stderr=subprocess.PIPE, timeout=60,
            ).strip()
        git("clone", "--shared", "--no-checkout", str(Path.cwd()), ".")
        git("config", "user.name", "GitHub Ship")
        git("config", "user.email", "github-ship@users.noreply.github.com")
        git("checkout", "--detach", root["sha"])
        try:
            git("rebase", "--onto", main, root["base"], root["sha"],
                "--reapply-cherry-picks", "--empty=stop", "--no-autosquash", "--no-update-refs")
        except subprocess.CalledProcessError as error:
            sys.stderr.write(error.stderr)
            raise ValueError("Clean rebase stopped on a conflict or empty commit; reconcile manually") from error
        sha = git("rev-parse", "HEAD")
        if git("rev-list", "--count", f"{main}..{sha}") != count:
            raise ValueError("Replay changed the number of task commits")
        ci.git("fetch", "--no-tags", directory, sha)
    record = dict(schemaVersion=2, rootSha=root["sha"], rootRun=root["run"],
                  rootAttempt=root["attempt"], previousSha=current["sha"],
                  generation=current["generation"] + 1, base=main, sha=sha,
                  run=int(os.environ["GITHUB_RUN_ID"]), attempt=int(os.environ["GITHUB_RUN_ATTEMPT"]))
    destination.parent.mkdir(parents=True, exist_ok=True)
    destination.write_text(json.dumps(record, sort_keys=True) + "\n")
    return {"state": "rebase_prepared", "root": root["sha"], "sha": sha, "base": main,
            "generation": record["generation"]}


def publish_successor(record):
    """Upload authority before atomically exposing both indexes and candidate CI."""
    root = find_request(record["rootSha"])
    if root is None or root.get("allow_clean_rebase") != "true":
        raise ValueError("No live clean-rebase authorization")
    if (record["run"] != int(os.environ["GITHUB_RUN_ID"])
            or record["attempt"] != int(os.environ["GITHUB_RUN_ATTEMPT"])):
        raise ValueError("Successor belongs to another producer attempt")
    run = api(f"actions/runs/{record['run']}")
    if download_record(run, SUCCESSOR) != record:
        raise ValueError("Upload the exact successor artifact before publication")
    generations = lineage(root)
    current = generations[-1]
    if (record["rootRun"] != root["run"] or record["rootAttempt"] != root["attempt"]
            or record["previousSha"] != current["sha"]
            or record["generation"] != current["generation"] + 1
            or record["generation"] > MAX_REBASES):
        raise ValueError("Another generation already owns this request; inspect its CI")
    if (any(api(f"git/matching-refs/tags/ship-revoked/{item['sha']}") for item in generations)
            or api(f"git/matching-refs/tags/ship-landed/{current['sha']}")):
        raise ValueError("Request was revoked or already landed before successor publication")
    ci.require_origin()
    branch = ci.candidate_branch(record["base"], record["sha"])
    tag = (f"object {record['sha']}\ntype commit\ntag ship-successor\n"
           "tagger GitHub Ship <github-ship@users.noreply.github.com> 0 +0000\n\n"
           + json.dumps(record, sort_keys=True) + "\n")
    object_sha = subprocess.check_output(["git", "hash-object", "-t", "tag", "-w", "--stdin"],
                                         input=tag, text=True).strip()
    targets = [f"refs/tags/{next_name(root, current['sha'])}",
               f"refs/tags/ship-source/{record['sha']}", f"refs/heads/{branch}"]
    # Tags are create-only; competing producers cannot replace a chosen generation.
    result = subprocess.run(
        ["git", "push", "--atomic", "origin", f"{object_sha}:{targets[0]}",
         f"{object_sha}:{targets[1]}", f"{record['sha']}:{targets[2]}"],
        text=True, capture_output=True, timeout=60,
    )
    sys.stderr.write(result.stdout + result.stderr)
    if result.returncode or "bypass" in (result.stdout + result.stderr).lower():
        raise ValueError("Successor push was not confirmed compliant; inspect refs before retrying")
    for target, expected in zip(targets, (object_sha, object_sha, record["sha"])):
        if ci.remote_sha(target) != expected:
            raise ValueError("Successor readback differs; inspect remote state")
    # Close the completion-before-publication race. If another replay is needed,
    # stop visibly rather than leave an unuploaded second artifact in this run.
    return advance({}, root)


def platform_ci(root, current):
    required = ci.REQUIRED | {name for key, name in (
        ("darwin", "Darwin-only checks"), ("services_vm", "Service VM Tests (Linux)"),
    ) if root.get(key) == "true"}
    if required == ci.REQUIRED:
        return True
    base, sha = current["base"], current["sha"]
    identity = f"{root['run']}-{root['attempt']}-{sha}"
    title = f"Ship validation {identity}"
    runs = ci.candidate_runs(base, sha, "workflow_dispatch", title)
    if not runs:
        name = f"ship-validation/{identity}"
        if api(f"git/matching-refs/tags/{name}"):
            raise ValueError(
                f"Native validation dispatch already claimed by {name}, but no correlated CI run is visible. "
                "Inspect the original Ship dispatch and Actions run before recovery. Do not redispatch."
            )
        api("git/refs", {"ref": f"refs/tags/{name}", "sha": sha})
        api("actions/workflows/ci.yml/dispatches", {
            "ref": ci.candidate_branch(base, sha), "inputs": {
                "darwin": root["darwin"], "services_vm": root["services_vm"],
                "ship_request": identity,
            },
        })
        return False
    if runs[0]["status"] != "completed":
        return False
    ci.passing_candidate(base, sha, "workflow_dispatch", title, required)
    return True


def advance(event, record=None, successor=None):
    """A CI event is a wake-up only; the saved dispatch supplies authority."""
    run = None
    if record is None:
        run = event["workflow_run"]
        if (run["path"] != ".github/workflows/ci.yml" or run["event"] not in {"push", "workflow_dispatch"}
                or run["repository"]["full_name"] != ci.REPOSITORY
                or run["head_repository"]["full_name"] != ci.REPOSITORY
                or not (run["head_branch"] == "main" or run["head_branch"].startswith("candidate/"))):
            return {"state": "unrelated"}
        record = find_request(run["head_sha"])
        if record is None:
            source = tag_record(f"ship-source/{run['head_sha']}")
            record = find_request(source["rootSha"]) if source else None
        if record is None:
            return {"state": "no_registered_request"}
    generations = lineage(record)
    current = generations[-1]
    if run:
        matching = [item for item in generations if item["sha"] == run["head_sha"]]
        if not matching or run["head_branch"] not in {"main", ci.candidate_branch(matching[0]["base"], run["head_sha"])}:
            raise ValueError("CI event is not for this Ship request")
        if run["event"] == "workflow_dispatch" and (
            run["head_branch"] == "main" or run["display_title"] !=
            f"Ship validation {record['run']}-{record['attempt']}-{run['head_sha']}"
        ):
            return {"state": "unrelated"}
    base, sha = current["base"], current["sha"]
    if any(api(f"git/matching-refs/tags/ship-revoked/{item['sha']}") for item in generations):
        raise ValueError("Ship authorization was revoked; inspect any accepted deployment")
    main = api("git/ref/heads/main")["object"]["sha"]
    rebase = record.get("allow_clean_rebase") == "true"
    landed_ref = f"refs/tags/ship-landed/{sha}"
    landed = api(f"git/matching-refs/tags/ship-landed/{sha}") if rebase else []
    if main not in {base, sha} and (not rebase or landed):
        raise ValueError("Main moved; shipping stopped without substituting another revision")
    runs = ci.candidate_runs(base, sha)
    if not runs or runs[0]["status"] != "completed":
        return {"state": "candidate_ci_pending"}
    ci.passing_candidate(base, sha)
    if not platform_ci(record, current):
        return {"state": "platform_ci_pending", "sha": sha}
    if main not in {base, sha}:
        return prepare_rebase(record, current, main, successor)
    if main == base:
        # Keep trusted main checked out for every subsequent workflow step.
        ci.git("fetch", "--no-tags", "origin", sha)
        try:
            ci.publish("land", base, sha, require_head=False)
        except ci.MainMoved:
            if not rebase:
                raise
            main = api("git/ref/heads/main")["object"]["sha"]
            return prepare_rebase(record, current, main, successor)
        api("git/refs", {"ref": landed_ref, "sha": sha})
    else:
        refs = api(f"git/matching-refs/tags/ship-landed/{sha}")
        if not any(item["ref"] == landed_ref and item["object"]["sha"] == sha for item in refs):
            raise ValueError("Main is published but compliant Ship landing is unproved; inspect the original run")
    if continuous():
        # Standing rollout owns activation; a task approval never dispatches,
        # so it cannot become approval for whatever main holds later.
        return {"state": "published", "sha": sha, "deployment":
                "standing_rollout" if record["deploy"] == "true" else "publication_only"}
    if record["deploy"] == "false":
        return {"state": "published", "sha": sha, "deployment": "not_authorized"}
    query = ci.urlencode(dict(branch="main", event="push", head_sha=sha, per_page=1))
    runs = api(f"actions/workflows/ci.yml/runs?{query}")["workflow_runs"]
    if not runs or runs[0]["status"] != "completed":
        return {"state": "main_ci_pending", "sha": sha}
    run = runs[0]
    if any(run.get(key) != value for key, value in dict(
        head_sha=sha, head_branch="main", event="push", path=".github/workflows/ci.yml",
        status="completed", conclusion="success",
    ).items()):
        raise ValueError("Latest exact-main CI did not succeed")
    if api("git/ref/heads/main")["object"]["sha"] != sha:
        raise ValueError("Main moved before deployment dispatch")
    if any(api(f"git/matching-refs/tags/ship-revoked/{item['sha']}") for item in generations):
        raise ValueError("Ship authorization was revoked before deployment dispatch")
    # A persistent, create-only claim prevents duplicate events/reruns from redeploying.
    # If the process dies after this write, investigate the failed run; never auto-retry.
    ref = f"refs/tags/ship-deploy/{sha}"
    refs = api(f"git/matching-refs/tags/ship-deploy/{sha}")
    if any(item["ref"] == ref for item in refs):
        raise ValueError("Deployment already claimed; inspect original Ship and Deploy NUC runs, never redispatch")
    api("git/refs", {"ref": ref, "sha": sha})
    api("actions/workflows/deploy-nuc.yml/dispatches",
        {"ref": "main", "inputs": {"expected_sha": sha}})
    return {"state": "deployment_requested", "sha": sha}


def revoke(sha):
    # A completed registration cannot be cancelled. Persist revocation separately.
    ci.candidate_branch("0" * 40, sha)
    ref = f"refs/tags/ship-revoked/{sha}"
    refs = api(f"git/matching-refs/tags/ship-revoked/{sha}")
    if not any(item["ref"] == ref for item in refs):
        api("git/refs", {"ref": ref, "sha": sha})
    return {"state": "revoked", "sha": sha,
            "nextAction": "Cancel any accepted Ship/Deploy NUC run and inspect actual host state."}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest="command", required=True)
    command = commands.add_parser("request")
    command.add_argument("--receipt", required=True, type=Path)
    for name in ("base", "sha", "thread", "authority"):
        command.add_argument(f"--{name}", required=True)
    command.add_argument("--deploy", action="store_true")
    for name in OPTIONS:
        command.add_argument(f"--{name.replace('_', '-')}", action="store_true")
    command = commands.add_parser("revoke")
    command.add_argument("--sha", required=True)
    command = commands.add_parser("publish-successor")
    command.add_argument("--record", required=True, type=Path)
    for name in ("register", "advance"):
        command = commands.add_parser(name)
        command.add_argument("--event", required=True, type=Path)
        if name == "advance":
            command.add_argument("--record", type=Path)
            command.add_argument("--successor", type=Path)
    args = parser.parse_args()
    try:
        if args.command == "request":
            result = request(args)
        elif args.command == "revoke":
            result = revoke(args.sha)
        elif args.command == "publish-successor":
            result = publish_successor(json.loads(args.record.read_text()))
        else:
            event = json.loads(args.event.read_text())
            if args.command == "register":
                result = register(event)
            else:
                result = advance(event, json.loads(args.record.read_text()) if args.record else None,
                                 args.successor)
        print(json.dumps(result, sort_keys=True))
        return 0
    except (ValueError, KeyError, TypeError, OSError, subprocess.SubprocessError) as error:
        print(f"Ship blocked: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
