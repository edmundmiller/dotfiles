#!/usr/bin/env python3
"""Submit a candidate for hosted CI, then fast-forward main to its exact green SHA.

Both submit and land publish Git refs and require explicit publication authority.
Neither command commits, rebases, polls, opens a PR, or deploys a host.
"""

import argparse
import json
import os
import re
import subprocess
import sys
from urllib.parse import urlencode

REPOSITORY = "edmundmiller/dotfiles"
REQUIRED = {"Flake Check (Linux)", "Check Formatting"}
SHA = r"[0-9a-f]{40}"


def git(*args):
    return subprocess.check_output(["git", *args], text=True).strip()


def candidate_branch(base, sha):
    if not re.fullmatch(SHA, base) or not re.fullmatch(SHA, sha) or base == sha:
        raise ValueError("Candidate requires distinct exact base and candidate SHAs")
    return f"candidate/{base}/{sha}"


def validation_base():
    """A new branch's zero before-SHA must not select an accidental full run."""
    ref = os.environ.get("GITHUB_REF_NAME", "")
    if os.environ.get("GITHUB_EVENT_NAME") != "push" or not ref.startswith("candidate/"):
        return os.environ.get("VALIDATION_BASE", "")
    match = re.fullmatch(f"candidate/({SHA})/({SHA})", ref)
    if not match:
        raise ValueError("Malformed candidate ref")
    base, sha = match.groups()
    candidate_branch(base, sha)
    if os.environ.get("GITHUB_SHA") != sha or git("rev-parse", "HEAD") != sha:
        raise ValueError("Candidate ref does not identify the checked out commit")
    if git("rev-parse", "origin/main") != base:
        raise ValueError("Main moved; reconcile and submit a new candidate")
    git("merge-base", "--is-ancestor", base, sha)
    return base


def github(endpoint, paginate=False):
    command = ["gh", "api", "--hostname", "github.com", f"repos/{REPOSITORY}/{endpoint}".rstrip("/")]
    if paginate:
        command += ["--paginate", "--slurp"]
    return json.loads(subprocess.check_output(command, text=True, timeout=30))


def passing_candidate(base, sha):
    branch = candidate_branch(base, sha)
    query = urlencode({"branch": branch, "event": "push", "head_sha": sha, "per_page": 1})
    endpoint = f"actions/workflows/ci.yml/runs?{query}"
    runs = github(endpoint)["workflow_runs"]
    if not runs:
        raise ValueError("Candidate CI has not started; resume on its completion event")
    run = runs[0]
    expected = {
        "head_sha": sha, "head_branch": branch, "event": "push",
        "path": ".github/workflows/ci.yml", "status": "completed", "conclusion": "success",
    }
    if any(run.get(key) != value for key, value in expected.items()):
        raise ValueError("Latest exact-candidate CI is not successful")
    if not isinstance(run.get("run_attempt"), int) or run["run_attempt"] < 1:
        raise ValueError("Missing CI attempt identity")
    pages = github(
        f"actions/runs/{run['id']}/attempts/{run['run_attempt']}/jobs?per_page=100",
        paginate=True,
    )
    jobs = [job for page in pages for job in page["jobs"] if job["name"] in REQUIRED]
    if len(jobs) != len(REQUIRED) or {job["name"] for job in jobs} != REQUIRED or any(
        job["conclusion"] != "success" for job in jobs
    ):
        raise ValueError("Required candidate checks are missing or unsuccessful")
    # A failed/running rerun must not be hidden behind an earlier successful attempt.
    if github(endpoint)["workflow_runs"] != runs:
        raise ValueError("CI changed during inspection; inspect the latest attempt again")
    return run["html_url"]


def remote_sha(ref):
    result = git("ls-remote", "--exit-code", "origin", ref).split()
    if len(result) != 2 or result[1] != ref:
        raise ValueError(f"Ambiguous remote ref: {ref}")
    return result[0]


def publish(command, base, sha):
    branch = candidate_branch(base, sha)
    urls = git("config", "--get-all", "remote.origin.url").splitlines()
    allowed = {
        f"https://github.com/{REPOSITORY}", f"https://github.com/{REPOSITORY}.git",
        f"git@github.com:{REPOSITORY}.git", f"ssh://git@github.com/{REPOSITORY}.git",
    }
    push_urls = subprocess.run(
        ["git", "config", "--get-all", "remote.origin.pushurl"], capture_output=True, text=True
    )
    if len(urls) != 1 or urls[0] not in allowed or push_urls.returncode != 1:
        raise ValueError("origin must name this GitHub repository without a separate push URL")
    if git("status", "--porcelain") or git("rev-parse", "HEAD") != sha:
        raise ValueError("Commit task changes first; HEAD must be the exact clean candidate")
    git("fetch", "--no-tags", "origin", "refs/heads/main:refs/remotes/origin/main")
    git("merge-base", "--is-ancestor", base, sha)
    if remote_sha("refs/heads/main") != base:
        raise ValueError("Main moved; reconcile, validate, and submit a new candidate")
    ci_url = None
    if command == "land":
        if remote_sha(f"refs/heads/{branch}") != sha:
            raise ValueError("Candidate ref no longer identifies the requested SHA")
        ci_url = passing_candidate(base, sha)
        if remote_sha("refs/heads/main") != base:
            raise ValueError("Main moved during CI inspection; submit a new candidate")
    target = "refs/heads/main" if command == "land" else f"refs/heads/{branch}"
    # No force option. An unrelated main update racing this push is rejected by Git.
    result = subprocess.run(
        ["git", "push", "origin", f"{sha}:{target}"], text=True, capture_output=True
    )
    sys.stderr.write(result.stdout + result.stderr)
    if result.returncode:
        raise ValueError("Push did not confirm success; inspect remote refs before retrying")
    if "bypass" in (result.stdout + result.stderr).lower():
        raise ValueError("Ref was published with a policy bypass; do not report compliant landing")
    if remote_sha(target) != sha:
        raise ValueError("Published ref changed; inspect remote state before continuing")
    return {"sha": sha, "base": base, "branch": branch, "ci": ci_url, "publishedRef": target}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest="command", required=True)
    commands.add_parser("base", help="Print the CI selection base without publishing")
    for name in ("submit", "land"):
        command = commands.add_parser(name)
        command.add_argument("--base", required=True)
        command.add_argument("--sha", required=True)
    args = parser.parse_args()
    try:
        if args.command == "base":
            print(validation_base())
        else:
            print(json.dumps(publish(args.command, args.base, args.sha), sort_keys=True))
        return 0
    except (ValueError, KeyError, subprocess.SubprocessError) as error:
        print(f"Candidate CI blocked: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
