#!/usr/bin/env python3
"""Publish explicit Git revisions from an isolated clone."""

from __future__ import annotations

import argparse
import json
from pathlib import Path
import re
import subprocess
import tempfile
from typing import Any


MAX_ATTEMPTS = 2
URL_CREDENTIALS = re.compile(
    r"(?P<prefix>(?:https?|ssh|git)://)(?P<credentials>[^/@\s]+)@"
)


def redact(value: str) -> str:
    return URL_CREDENTIALS.sub(r"\g<prefix><redacted>@", value)


class PublishError(Exception):
    """A safe, actionable publication failure."""


class CommandError(PublishError):
    def __init__(self, args: list[str], stderr: str) -> None:
        detail = stderr.strip().splitlines()[-1] if stderr.strip() else "command failed"
        safe_args = [redact(arg) for arg in args]
        super().__init__(f"{' '.join(safe_args)}: {redact(detail)}")


def run_git(
    cwd: Path | None, args: list[str], *, check: bool = True
) -> subprocess.CompletedProcess[str]:
    result = subprocess.run(
        ["git", *args],
        cwd=cwd,
        capture_output=True,
        text=True,
        check=False,
    )
    if check and result.returncode != 0:
        raise CommandError(["git", *args], result.stderr)
    return result


def git_output(cwd: Path, *args: str) -> str:
    result = run_git(cwd, list(args))
    return result.stdout.strip()


def optional_git_output(cwd: Path, *args: str) -> str | None:
    result = run_git(cwd, list(args), check=False)
    value = result.stdout.strip()
    return value if result.returncode == 0 and value else None


def remote_names(source: Path) -> list[str]:
    return [name for name in git_output(source, "remote").splitlines() if name]


def remote_url(source: Path, remote: str) -> str:
    return git_output(source, "remote", "get-url", remote)


def upstream_remote(source: Path) -> tuple[str, str] | None:
    upstream = optional_git_output(
        source, "rev-parse", "--abbrev-ref", "--symbolic-full-name", "@{upstream}"
    )
    if not upstream or "/" not in upstream:
        return None
    return upstream.split("/", 1)


def discover_remote(source: Path, requested: str | None) -> str:
    names = remote_names(source)
    if requested:
        if requested not in names:
            raise PublishError(f"remote is not configured in source repository: {requested}")
        return requested
    upstream = upstream_remote(source)
    if upstream and upstream[0] in names:
        return upstream[0]
    candidates = [
        name
        for name in names
        if optional_git_output(source, "symbolic-ref", f"refs/remotes/{name}/HEAD")
    ]
    if len(candidates) == 1:
        return candidates[0]
    if len(names) == 1:
        return names[0]
    if not names:
        raise PublishError("source repository has no configured remote")
    raise PublishError("cannot discover a unique remote; pass --remote")


def branch_from_remote_head(url: str) -> str | None:
    result = run_git(None, ["ls-remote", "--symref", url, "HEAD"], check=False)
    if result.returncode != 0:
        return None
    for line in result.stdout.splitlines():
        if line.startswith("ref: refs/heads/") and line.endswith("\tHEAD"):
            return line.removeprefix("ref: refs/heads/").removesuffix("\tHEAD")
    return None


def discover_branch(
    source: Path, remote: str, url: str, requested: str | None
) -> str:
    if requested:
        return requested
    branch = branch_from_remote_head(url)
    if branch:
        return branch
    raise PublishError(f"cannot discover default branch for remote {remote}; pass --default-branch")


def resolve_revisions(source: Path, revisions: list[str]) -> list[str]:
    resolved: list[str] = []
    for revision in revisions:
        commit = optional_git_output(source, "rev-parse", "--verify", f"{revision}^{{commit}}")
        if not commit:
            raise PublishError(f"task revision is not a commit in source repository: {revision}")
        if commit in resolved:
            raise PublishError(f"task revision was repeated: {commit}")
        resolved.append(commit)
    return resolved


def fetch_task_objects(clone: Path, source: Path, revisions: list[str]) -> None:
    for revision in revisions:
        run_git(clone, ["fetch", "--no-tags", str(source), revision])


def classify_revision(clone: Path, remote_ref: str, revision: str) -> str:
    if run_git(
        clone, ["merge-base", "--is-ancestor", revision, remote_ref], check=False
    ).returncode == 0:
        return "exact"
    parent = optional_git_output(clone, "rev-parse", f"{revision}^")
    if not parent:
        return "unlanded"
    cherry = run_git(clone, ["cherry", remote_ref, revision, parent], check=False)
    if cherry.returncode == 0 and any(
        line.startswith("-") for line in cherry.stdout.splitlines()
    ):
        return "patch-equivalent"
    return "unlanded"


def classify_revisions(
    clone: Path, remote_ref: str, revisions: list[str]
) -> list[dict[str, str]]:
    return [
        {"revision": revision, "evidence": classify_revision(clone, remote_ref, revision)}
        for revision in revisions
    ]


def replay_unlanded(clone: Path, classifications: list[dict[str, str]]) -> None:
    for item in classifications:
        if item["evidence"] == "unlanded":
            run_git(clone, ["cherry-pick", "--no-edit", item["revision"]])


def authoritative_tip(url: str, branch: str) -> str:
    result = run_git(None, ["ls-remote", "--exit-code", url, f"refs/heads/{branch}"])
    line = result.stdout.splitlines()[0] if result.stdout.splitlines() else ""
    tip = line.split()[0] if line else ""
    if not tip:
        raise PublishError(f"authoritative remote has no {branch} branch")
    return tip


def verify_publication(
    clone: Path, url: str, branch: str, revisions: list[str]
) -> tuple[str, str, list[dict[str, str]]]:
    run_git(clone, ["fetch", "--no-tags", "origin", branch])
    local_tip = git_output(clone, "rev-parse", branch)
    remote_tip = authoritative_tip(url, branch)
    if local_tip != remote_tip:
        raise PublishError(
            f"publication verification mismatch: local {local_tip} != remote {remote_tip}"
        )
    remote_ref = f"origin/{branch}"
    classifications = classify_revisions(clone, remote_ref, revisions)
    unlanded = [item["revision"] for item in classifications if item["evidence"] == "unlanded"]
    if unlanded:
        raise PublishError(f"published tip does not contain task revisions: {', '.join(unlanded)}")
    return local_tip, remote_tip, classifications


def is_non_fast_forward(result: subprocess.CompletedProcess[str]) -> bool:
    output = f"{result.stdout}\n{result.stderr}".lower()
    return any(
        phrase in output
        for phrase in ("non-fast-forward", "fetch first", "[rejected]")
    )


def publish(args: argparse.Namespace) -> dict[str, Any]:
    source = Path(args.source_repo).expanduser().resolve()
    if not source.is_dir():
        raise PublishError(f"source repository is inaccessible: {source}")
    source_root = Path(git_output(source, "rev-parse", "--show-toplevel")).resolve()
    remote = discover_remote(source_root, args.remote)
    url = remote_url(source_root, remote)
    branch = discover_branch(source_root, remote, url, args.default_branch)
    revisions = resolve_revisions(source_root, args.task_revision)

    with tempfile.TemporaryDirectory(prefix="done-publish-") as temporary:
        clone = Path(temporary) / "repository"
        run_git(
            None,
            [
                "clone",
                "--no-tags",
                "--single-branch",
                "--branch",
                branch,
                url,
                str(clone),
            ],
        )
        fetch_task_objects(clone, source_root, revisions)

        attempts = 0
        initial_classifications: list[dict[str, str]] | None = None
        while attempts < MAX_ATTEMPTS:
            attempts += 1
            if attempts > 1:
                run_git(clone, ["fetch", "--no-tags", "origin", branch])
                run_git(clone, ["reset", "--hard", f"origin/{branch}"])
            classifications = classify_revisions(clone, f"origin/{branch}", revisions)
            if initial_classifications is None:
                initial_classifications = classifications
            replay_unlanded(clone, classifications)
            if not any(item["evidence"] == "unlanded" for item in classifications):
                local_tip, remote_tip, final = verify_publication(
                    clone, url, branch, revisions
                )
                return {
                    "status": "already-landed",
                    "remote": remote,
                    "defaultBranch": branch,
                    "sourceRepository": str(source_root),
                    "attempts": attempts,
                    "taskRevisions": final,
                    "integratedTip": local_tip,
                    "remoteTip": remote_tip,
                }

            pushed = run_git(
                clone,
                ["push", "origin", f"HEAD:refs/heads/{branch}"],
                check=False,
            )
            if pushed.returncode == 0:
                local_tip, remote_tip, final = verify_publication(
                    clone, url, branch, revisions
                )
                for item in final:
                    initial = next(
                        record
                        for record in initial_classifications or []
                        if record["revision"] == item["revision"]
                    )
                    item["initialEvidence"] = initial["evidence"]
                return {
                    "status": "published",
                    "remote": remote,
                    "defaultBranch": branch,
                    "sourceRepository": str(source_root),
                    "attempts": attempts,
                    "taskRevisions": final,
                    "integratedTip": local_tip,
                    "remoteTip": remote_tip,
                }
            if attempts == MAX_ATTEMPTS or not is_non_fast_forward(pushed):
                detail = (
                    pushed.stderr.strip().splitlines()[-1]
                    if pushed.stderr.strip()
                    else "push failed"
                )
                raise PublishError(f"normal push rejected: {redact(detail)}")

        raise PublishError("remote kept advancing after one retry")


def parser() -> argparse.ArgumentParser:
    result = argparse.ArgumentParser(description=__doc__)
    result.add_argument("--source-repo", required=True)
    result.add_argument("--task-revision", action="append", required=True)
    result.add_argument("--remote")
    result.add_argument("--default-branch")
    return result


def main() -> int:
    try:
        payload = publish(parser().parse_args())
    except PublishError as error:
        print(json.dumps({"status": "blocked", "error": str(error)}, sort_keys=True))
        return 1
    print(json.dumps(payload, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
