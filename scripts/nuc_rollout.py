#!/usr/bin/env python3
"""Continuous NUC rollout: pick the newest green published commit, classify the result.

Standing authority is the repository variable NUC_ROLLOUT=continuous, never a
per-task Ship approval. Commits opt out with an `NUC-Rollout:` trailer:
`publication-only` never triggers activation by itself; `hold` stops automatic
rollout before that commit until a human deploys an exact SHA past it.

Commands never retry a failed target: a newer green descendant is the retry.
"""

import argparse
import json
import os
from pathlib import Path
import re
import subprocess
import sys
from urllib.parse import urlencode

import candidate_ci as ci

SHA = re.compile(r"[0-9a-f]{40}")
TRAILER = "NUC-Rollout"
OPT_OUTS = {"publication-only", "hold"}
DEPLOYED, BLOCKED, DEFERRED = "nuc-rollout-deployed", "nuc-rollout-blocked", "nuc-rollout-deferred"
PENDING = {"queued", "in_progress", "waiting", "requested", "pending"}
WINDOW = 100  # First-parent commits a routine catch-up may span.


def failed_marker(sha):
    return f"nuc-rollout-failed-{sha}"


def trailers(rev_range):
    """Map each commit in a range to its lowercase NUC-Rollout values."""
    out = ci.git("log", "--format=%H%x00%(trailers:key=" + TRAILER + ",valueonly,separator=%x2C)%x1e",
                 rev_range)
    result = {}
    for entry in filter(None, (item.strip() for item in out.split("\x1e"))):
        sha, _, values = entry.partition("\x00")
        result[sha] = {value.strip().lower() for value in values.split(",") if value.strip()}
    for sha, values in result.items():
        if values - OPT_OUTS:
            raise ValueError(f"Unknown {TRAILER} trailer on {sha}: {sorted(values - OPT_OUTS)}")
    return result


def artifacts(name):
    query = urlencode({"name": name, "per_page": 100})
    return [item for item in ci.github(f"actions/artifacts?{query}")["artifacts"]
            if item["name"] == name and not item["expired"]]


def latest(name):
    return max((item["created_at"] for item in artifacts(name)), default="")


def main_ci_states():
    """Latest main-push CI attempt per commit; a newer failed rerun hides an older success."""
    query = urlencode({"branch": "main", "event": "push", "per_page": 100})
    runs = ci.github(f"actions/workflows/ci.yml/runs?{query}")["workflow_runs"]
    states = {}
    for run in sorted(runs, key=lambda item: item["id"]):
        if (run["head_branch"] != "main" or run["event"] != "push"
                or run["path"] != ".github/workflows/ci.yml"):
            raise ValueError("CI identity mismatch")
        states[run["head_sha"]] = (run["conclusion"] if run["status"] == "completed" else "pending")
    return states


def verify_main_ci(sha):
    """Recheck the selected target immediately before invoking host activation."""
    if not SHA.fullmatch(sha) or main_ci_states().get(sha) != "success":
        raise ValueError("Latest main-push CI for the selected revision did not succeed")
    return {"outcome": "ci_verified", "target": sha}


def parse_active(configuration_revision):
    match = re.fullmatch(r"dotfiles=([0-9a-f]{40});agents-workspace=[0-9a-f]{40}",
                         configuration_revision.strip())
    return match.group(1) if match else None


def select(main, active):
    """Choose a target without touching the host. Every non-target answer is final for this run."""
    if not SHA.fullmatch(main):
        raise ValueError("Live main must be an exact SHA")
    if latest(BLOCKED) > latest(DEPLOYED):
        return {"outcome": "blocked", "reason": "An earlier rollout left an unknown host state; "
                "a human must inspect it or deploy an exact SHA."}
    if active is None:
        return {"outcome": "unknown_active", "reason": "Active configurationRevision is unreadable"}
    ancestor = subprocess.run(["git", "merge-base", "--is-ancestor", active, main], check=False)
    if ancestor.returncode:
        return {"outcome": "diverged", "active": active,
                "reason": "Active revision is not published on main; never downgrade automatically"}
    if active == main:
        return {"outcome": "current", "active": active}
    if int(ci.git("rev-list", "--count", "--first-parent", f"{active}..{main}")) > WINDOW:
        return {"outcome": "diverged", "active": active,
                "reason": f"More than {WINDOW} commits behind main; deploy an exact SHA manually"}
    tags = trailers(f"{active}..{main}")
    line = ci.git("rev-list", "--first-parent", f"{active}..{main}").split()
    states = main_ci_states()
    skipped, held = [], None
    for position, sha in enumerate(line):
        commits = ci.git("rev-list", f"{active}..{sha}").split()
        holds = [commit for commit in commits if "hold" in tags.get(commit, set())]
        if holds:
            # Never pass a hold automatically; only older commits remain candidates.
            held = holds[-1]
            skipped.append({"sha": sha, "reason": "held"})
            continue
        if states.get(sha) != "success":
            skipped.append({"sha": sha, "reason": f"ci_{states.get(sha, 'missing')}"})
            continue
        if artifacts(failed_marker(sha)):
            # Only this exact SHA is excluded; a newer green descendant stays eligible.
            skipped.append({"sha": sha, "reason": "earlier_rollout_failed"})
            continue
        if all("publication-only" in tags.get(commit, set()) for commit in commits):
            return {"outcome": "nothing_to_activate", "active": active, "head": sha,
                    "skipped": skipped, "held": held}
        return {"outcome": "selected", "active": active, "target": sha, "skipped": skipped,
                "superseded": position, "held": held}
    return {"outcome": "nothing_eligible", "active": active, "skipped": skipped, "held": held}


def classify(previous, target, active, activation, health, log):
    """Classify from host readback, never from the exit status alone."""
    if activation == "success" and health == "success" and active == target:
        return "deployed"
    if "NUC deployment lock is held" in log and active == previous:
        return "host_busy"
    if active == previous:
        return "not_activated"
    if active == target:
        return "activated_unhealthy"
    return "unknown"


NEXT = {
    "deployed": "None.",
    "host_busy": "Deferred: another deployment held the host lock. The next trigger or hourly sweep retries.",
    "not_activated": "Host unchanged on the previous generation. Fix forward with a new commit; this SHA is never retried automatically.",
    "activated_unhealthy": "Target is active but health failed. Repair forward or run `hey nuc rollback`; this SHA is never retried automatically.",
    "unknown": "Neither revision is active. Automatic rollout is blocked until a human inspects the host or deploys an exact SHA.",
}


def report(args):
    try:
        readback = json.loads(args.readback.read_text()) if args.readback and args.readback.exists() else {}
    except json.JSONDecodeError:
        readback = {}  # Interrupted SSH can leave a partial file: host state is unknown.
    active = parse_active(readback.get("configurationRevision", ""))
    log = args.log.read_text(errors="replace") if args.log and args.log.exists() else ""
    changed = readback.get("changedUnits", [])
    unhealthy = [unit for unit in changed if unit.get("ActiveState") not in {"active", "inactive"}
                 or unit.get("Result") != "success"]
    classification = classify(args.previous, args.target, active, args.activation,
                              "failure" if unhealthy else args.health, log)
    return {
        "schemaVersion": 1, "outcome": classification, "target": args.target,
        "previous": args.previous, "active": active, "main": args.main,
        "activation": args.activation, "health": args.health,
        "changedUnits": changed,
        "unhealthyChangedUnits": unhealthy,
        "failedUnits": readback.get("failedUnits", []),
        "currentSystem": readback.get("currentSystem"), "bootedSystem": readback.get("bootedSystem"),
        "run": f"{os.environ.get('GITHUB_SERVER_URL', 'https://github.com')}/{ci.REPOSITORY}"
               f"/actions/runs/{os.environ.get('GITHUB_RUN_ID', '0')}",
        "next": NEXT[classification],
    }


def summary(result):
    lines = [f"## NUC rollout: {result['outcome']}", ""]
    for key in ("target", "previous", "active", "main", "held", "reason"):
        if result.get(key):
            value = result[key]
            lines.append(f"- {key}: `{value}`" if SHA.fullmatch(str(value)) else f"- {key}: {value}")
    if result.get("failedUnits"):
        lines.append(f"- failed units: {', '.join(result['failedUnits'])}")
    if result.get("unhealthyChangedUnits"):
        lines.append(f"- unhealthy changed units: {', '.join(u['Id'] for u in result['unhealthyChangedUnits'])}")
    if result.get("changedUnits"):
        lines.append(f"- changed units: {len(result['changedUnits'])}")
    if result.get("next"):
        lines.append(f"- next: {result['next']}")
    return "\n".join(lines) + "\n"


def dispatch(retry_deferred=False):
    """Wake-up only: dispatch one rollout when current main has not been evaluated yet.

    A host-busy (deferred) result is retried only by the sweep or a manual wake-up,
    so a held lock cannot turn completion events into a dispatch loop."""
    if os.environ.get("NUC_ROLLOUT") != "continuous":
        return {"state": "rollout_disabled"}
    main = ci.github("git/ref/heads/main")["object"]["sha"]
    query = urlencode({"branch": "main", "event": "push", "head_sha": main, "per_page": 1})
    runs = ci.github(f"actions/workflows/ci.yml/runs?{query}")["workflow_runs"]
    if not runs or runs[0]["status"] != "completed":
        return {"state": "main_ci_pending", "main": main}  # Its completion wakes us again.
    deploys = ci.github("actions/workflows/deploy-nuc.yml/runs?per_page=50")["workflow_runs"]
    if any(run["status"] in PENDING - {"in_progress"} for run in deploys):
        # A pending rollout selects live main when it starts; never displace a pending manual run.
        return {"state": "deploy_pending", "main": main}
    for run in deploys:
        if run["display_title"] == f"Roll out NUC {main}" and run["conclusion"] != "cancelled":
            if run["status"] in PENDING:
                return {"state": "rollout_running", "main": main}
            names = {item["name"] for item in ci.github(f"actions/runs/{run['id']}/artifacts")["artifacts"]}
            if DEFERRED not in names or not retry_deferred:
                return {"state": "already_evaluated", "main": main, "run": run["html_url"]}
            break
    payload = json.dumps({"ref": "main", "inputs": {"expected_sha": main, "operation": "rollout"}})
    subprocess.run(["gh", "api", "--hostname", "github.com",
                    f"repos/{ci.REPOSITORY}/actions/workflows/deploy-nuc.yml/dispatches",
                    "--method", "POST", "--input", "-"], input=payload, text=True,
                   check=True, timeout=30)
    return {"state": "rollout_requested", "main": main}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest="command", required=True)
    command = commands.add_parser("dispatch")
    command.add_argument("--retry-deferred", action="store_true")
    command = commands.add_parser("select")
    command.add_argument("--main", required=True)
    command.add_argument("--configuration-revision", required=True)
    commands.add_parser("verify").add_argument("--sha", required=True)
    command = commands.add_parser("report")
    for name in ("previous", "target", "main", "activation", "health"):
        command.add_argument(f"--{name}", required=True)
    command.add_argument("--readback", type=Path)
    command.add_argument("--log", type=Path)
    args = parser.parse_args()
    try:
        if args.command == "dispatch":
            result = dispatch(args.retry_deferred)
        elif args.command == "select":
            result = select(args.main, parse_active(args.configuration_revision))
        elif args.command == "verify":
            result = verify_main_ci(args.sha)
        else:
            result = report(args)
        print(json.dumps(result, sort_keys=True))
        if args.command != "dispatch" and os.environ.get("GITHUB_STEP_SUMMARY"):
            with open(os.environ["GITHUB_STEP_SUMMARY"], "a") as stream:
                stream.write(summary(result))
        return 0
    except (ValueError, KeyError, TypeError, OSError, subprocess.SubprocessError) as error:
        print(f"NUC rollout blocked: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
