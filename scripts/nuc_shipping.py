#!/usr/bin/env -S uv run --script
# /// script
# dependencies = []
# ///
"""Submit an exact-SHA NUC deployment request; GitHub owns CI waiting.

The owner keeps one existing agent-run receipt until deployment is verified.
Only this command writes that receipt while a request is being submitted.
It records authority; it does not grant it or replace GitHub's deployment gates.
"""

import argparse
from datetime import datetime, timezone
import fcntl
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import tempfile

REPOSITORY = "edmundmiller/dotfiles"
API_ROOT = f"repos/{REPOSITORY}"


def github_api(endpoint, payload=None, paginate=False):
    """Read GitHub state or make one dispatch attempt; never retry writes."""
    command = ["gh", "api", endpoint]
    if paginate:
        command += ["--paginate", "--slurp"]
    if payload is not None:
        command += ["--method", "POST", "--input", "-"]
    result = subprocess.run(
        command,
        input=json.dumps(payload) if payload is not None else None,
        text=True,
        capture_output=True,
        timeout=30,
        check=True,
    )
    return json.loads(result.stdout) if result.stdout.strip() else None


def save_shipping_receipt(path, receipt):
    """Persist the claim before dispatch, including across process termination."""
    fd, temporary = tempfile.mkstemp(prefix=path.name + ".", dir=path.parent)
    try:
        with os.fdopen(fd, "w") as stream:
            stream.write(json.dumps(receipt, indent=2, sort_keys=True) + "\n")
            stream.flush()
            os.fsync(stream.fileno())
        os.replace(temporary, path)
        directory = os.open(path.parent, os.O_RDONLY)
        try:
            os.fsync(directory)
        finally:
            os.close(directory)
    finally:
        if os.path.exists(temporary):
            os.unlink(temporary)


def reconcile_shipping_dispatch(shipping):
    """Identify an ambiguous dispatch without issuing another write."""
    if shipping.get("deploymentRunId"):
        return
    pages = github_api(
        f"{API_ROOT}/actions/workflows/deploy-nuc.yml/runs"
        f"?event=workflow_dispatch&created=%3E%3D{shipping['dispatchStartedAt']}&per_page=100",
        paginate=True,
    )
    matches = [
        run
        for page in pages
        for run in page["workflow_runs"]
        if run["display_title"] == f"Deploy NUC {shipping['sha']}"
        and run["actor"]["login"] == shipping["actor"]
        and run["event"] == "workflow_dispatch"
        and run["created_at"] >= shipping["dispatchStartedAt"]
    ]
    # A raced dispatch has another head SHA but retains expected_sha in its title.
    if len(matches) == 1:
        shipping.update(
            state="dispatched",
            deploymentRunId=matches[0]["id"],
            deploymentRunUrl=matches[0]["html_url"],
            nextAction="Inspect this deployment run on its completion event; verify logs before closeout.",
        )
    else:
        shipping["nextAction"] = (
            "Dispatch is not uniquely visible. Reconcile on a later event or operator request; never redispatch."
        )


def shipping_command(args, receipt, path):
    """Submit once or reconcile a request without transferring CI waiting to the caller."""
    if receipt.get("schemaVersion") != 2 or receipt.get("status") != "active":
        raise ValueError("NUC shipping requires an active schema-v2 agent-run receipt")
    shipping = receipt.get("nucShipping")
    if args.command == "reconcile":
        if not shipping or shipping["state"] not in ("dispatch_unknown", "dispatched"):
            raise ValueError("NUC shipping has no dispatch to reconcile")
        reconcile_shipping_dispatch(shipping)
        return
    if not re.fullmatch(r"[0-9a-f]{40}", args.sha):
        raise ValueError("NUC shipping requires an exact 40-character lowercase SHA")
    if args.recover_orb_pilot and not args.orb_pilot:
        raise ValueError("Pilot recovery requires --orb-pilot capacity and backend checks")
    if shipping:
        if (shipping["sha"], shipping["ownerThread"]) != (args.sha, args.thread):
            raise ValueError(
                "NUC shipping already recorded for another revision or owner"
            )
        if shipping.get("orbPilot", False) != args.orb_pilot:
            raise ValueError("NUC shipping already recorded with different pilot checks")
        if shipping.get("recoverOrbPilot", False) != args.recover_orb_pilot:
            raise ValueError("NUC shipping already recorded with different pilot recovery")
        if shipping.get("haMonitor", False) != args.ha_monitor:
            raise ValueError("NUC shipping already recorded with different HA monitor setup")
        if args.no_deploy and shipping["state"] in ("dispatch_unknown", "dispatched"):
            raise ValueError(
                "NUC shipping already submitted: cancel the identified GitHub run to revoke it"
            )
        if shipping["state"] in ("dispatch_unknown", "dispatched"):
            reconcile_shipping_dispatch(shipping)
            return
        if shipping["state"] == "skipped":
            if not args.no_deploy:
                raise ValueError(
                    "NUC shipping was explicitly skipped; new deployment authority needs a new receipt"
                )
            return
    if not args.no_deploy and (
        receipt.get("authority", {}).get("mode") != "full"
        or not args.deployment_authority.strip()
    ):
        raise ValueError(
            "NUC shipping requires full closeout authority and explicit deployment authorization"
        )
    if not shipping:
        shipping = receipt["nucShipping"] = {
            "repository": REPOSITORY,
            "branch": "main",
            "workflow": "deploy-nuc.yml",
            "sha": args.sha,
            "ownerThread": args.thread,
            "deploymentAuthority": args.deployment_authority,
            "orbPilot": args.orb_pilot,
            "recoverOrbPilot": args.recover_orb_pilot,
            "haMonitor": args.ha_monitor,
            "state": "request_pending",
            "nextAction": "Submit the authorized request after confirming GitHub access and exact main.",
        }
    if args.no_deploy:
        shipping.update(
            state="skipped",
            nextAction="Deployment skipped by explicit no-deploy; no request submitted.",
        )
        return
    save_shipping_receipt(path, receipt)
    actor = github_api("user")["login"]
    if shipping.get("actor", actor) != actor:
        raise ValueError("NUC shipping blocked: authenticated GitHub actor changed")
    if github_api(f"{API_ROOT}/git/ref/heads/main")["object"]["sha"] != shipping["sha"]:
        raise ValueError(
            "NUC shipping blocked: main moved; unrelated changes need new authorization"
        )
    shipping.update(
        state="dispatch_unknown",
        actor=actor,
        dispatchStartedAt=datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        nextAction="Reconcile dispatch before any retry; acceptance is not deployment success.",
    )
    save_shipping_receipt(path, receipt)
    inputs = {"expected_sha": shipping["sha"]}
    if shipping.get("orbPilot", False):
        inputs["orb_pilot"] = "true"
    if shipping.get("recoverOrbPilot", False):
        inputs["recover_orb_pilot"] = "true"
    if shipping.get("haMonitor", False):
        inputs["ha_monitor"] = "true"
    github_api(
        f"{API_ROOT}/actions/workflows/deploy-nuc.yml/dispatches",
        {"ref": "main", "inputs": inputs},
    )
    shipping["state"] = "dispatched"
    save_shipping_receipt(path, receipt)
    reconcile_shipping_dispatch(shipping)


def main():
    """The shipping CLI submits or reconciles one GitHub-owned deployment request."""
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--receipt", required=True, type=Path)
    commands = parser.add_subparsers(dest="command", required=True)
    request = commands.add_parser(
        "request",
        help="Submit an authorized exact-SHA request immediately; GitHub waits for CI",
    )
    request.add_argument("--sha", required=True)
    request.add_argument("--thread", required=True)
    request.add_argument(
        "--orb-pilot",
        action="store_true",
        help="Run the approved pilot capacity and backend tests during deployment",
    )
    request.add_argument(
        "--recover-orb-pilot",
        action="store_true",
        help="Stop only dedicated pilot containers and release inherited locks; preserve disks",
    )
    request.add_argument(
        "--ha-monitor",
        action="store_true",
        help="Arm the approved HA runtime monitor for Gatus and verify live timer runs",
    )
    request.add_argument(
        "--no-deploy",
        action="store_true",
        help="Record an explicit skip without contacting GitHub",
    )
    request.add_argument(
        "--deployment-authority",
        default="",
        help="Reference to explicit authorization, not inferred from a push",
    )
    commands.add_parser(
        "reconcile", help="Identify an uncertain dispatch without submitting another"
    )
    args = parser.parse_args()
    try:
        path = args.receipt.expanduser().resolve(strict=True)
        # Keep one owner and receipt. Other receipt writers must wait until this
        # continuation finishes; this lock serializes duplicate event deliveries.
        with path.with_suffix(path.suffix + ".shipping-lock").open("a") as lock:
            fcntl.flock(lock, fcntl.LOCK_EX)
            receipt = json.loads(path.read_text())
            shipping_command(args, receipt, path)
            save_shipping_receipt(path, receipt)
            print(json.dumps(receipt["nucShipping"], sort_keys=True))
        return 0
    except (ValueError, KeyError, OSError, subprocess.SubprocessError) as error:
        print(f"NUC shipping stopped: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
