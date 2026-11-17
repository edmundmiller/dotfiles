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

WORKFLOW = ".github/workflows/ship.yml"
ARTIFACT = "ship-request-v1"


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
        if receipt.get("nucShipping"):
            raise ValueError("This receipt already owns a direct NUC request; do not mix shipping routes")
        previous = receipt.get("shipRequest")
        if previous:
            if previous["inputs"] != inputs:
                raise ValueError("A different Ship request already owns this receipt")
            if previous["state"] == "dispatch_unknown":
                raise ValueError("Ship dispatch is uncertain; inspect Actions before any retry")
            return previous
        if api("git/ref/heads/main")["object"]["sha"] != args.base:
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
    """Only an explicit dispatch on the captured base creates an authorization record."""
    inputs = event["inputs"]
    base, sha = inputs["base"], inputs["sha"]
    branch = ci.candidate_branch(base, sha)
    if (event["ref"] != "refs/heads/main" or os.environ["GITHUB_SHA"] != base
            or inputs["deploy"] not in {"true", "false"}
            or not inputs["authority"].strip() or not inputs["owner"].strip()):
        raise ValueError("Ship requires explicit authority on the exact main base")
    if api("git/ref/heads/main")["object"]["sha"] != base:
        raise ValueError("Main moved before Ship registration")
    if api(f"git/ref/heads/{branch}")["object"]["sha"] != sha:
        raise ValueError("Candidate ref differs from the authorized revision")
    ci.git("fetch", "--no-tags", "origin", sha)
    ci.git("merge-base", "--is-ancestor", base, sha)
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
    name = f"{ARTIFACT}-{run['run_attempt']}"
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
    if (record["run"] != run["id"] or record["attempt"] != run["run_attempt"]
            or record["base"] != run["head_sha"] or record["sha"] != sha
            or record["deploy"] not in {"true", "false"}
            or not record["authority"].strip() or not record["owner"].strip()):
        raise ValueError("Ship authorization does not bind this exact revision and attempt")
    ci.candidate_branch(record["base"], sha)
    return record


def advance(event, record=None):
    """A CI event is a wake-up only; the saved dispatch supplies authority."""
    if record is None:
        run = event["workflow_run"]
        if (run["path"] != ".github/workflows/ci.yml" or run["event"] != "push"
                or run["repository"]["full_name"] != ci.REPOSITORY
                or run["head_repository"]["full_name"] != ci.REPOSITORY
                or not (run["head_branch"] == "main" or run["head_branch"].startswith("candidate/"))):
            return {"state": "unrelated"}
        record = find_request(run["head_sha"])
        if record is None:
            return {"state": "no_registered_request"}
        expected = {"main", ci.candidate_branch(record["base"], record["sha"])}
        if run["head_branch"] not in expected:
            raise ValueError("CI event is not for this Ship request")
    base, sha = record["base"], record["sha"]
    if api(f"git/matching-refs/tags/ship-revoked/{sha}"):
        raise ValueError("Ship authorization was revoked; inspect any accepted deployment")
    main = api("git/ref/heads/main")["object"]["sha"]
    if main not in {base, sha}:
        raise ValueError("Main moved; shipping stopped without substituting another revision")
    branch = ci.candidate_branch(base, sha)
    query = ci.urlencode(dict(branch=branch, event="push", head_sha=sha, per_page=1))
    runs = api(f"actions/workflows/ci.yml/runs?{query}")["workflow_runs"]
    if not runs or runs[0]["status"] != "completed":
        return {"state": "candidate_ci_pending"}
    ci.passing_candidate(base, sha)
    landed_ref = f"refs/tags/ship-landed/{sha}"
    if main == base:
        # This process imported trusted main's helpers before changing the checkout.
        ci.git("fetch", "--no-tags", "origin", sha)
        ci.git("checkout", "--detach", sha)
        ci.publish("land", base, sha)
        api("git/refs", {"ref": landed_ref, "sha": sha})
    else:
        refs = api(f"git/matching-refs/tags/ship-landed/{sha}")
        if not any(item["ref"] == landed_ref and item["object"]["sha"] == sha for item in refs):
            raise ValueError("Main is published but compliant Ship landing is unproved; inspect the original run")
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
    if api(f"git/matching-refs/tags/ship-revoked/{sha}"):
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
    command = commands.add_parser("revoke")
    command.add_argument("--sha", required=True)
    for name in ("register", "advance"):
        command = commands.add_parser(name)
        command.add_argument("--event", required=True, type=Path)
        if name == "advance":
            command.add_argument("--record", type=Path)
    args = parser.parse_args()
    try:
        if args.command == "request":
            result = request(args)
        elif args.command == "revoke":
            result = revoke(args.sha)
        else:
            event = json.loads(args.event.read_text())
            if args.command == "register":
                result = register(event)
            else:
                result = advance(event, json.loads(args.record.read_text()) if args.record else None)
        print(json.dumps(result, sort_keys=True))
        return 0
    except (ValueError, KeyError, TypeError, OSError, subprocess.SubprocessError) as error:
        print(f"Ship blocked: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
