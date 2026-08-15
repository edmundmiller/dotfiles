#!/usr/bin/env -S uv run --script
#
# /// script
# requires-python = ">=3.11"
# dependencies = []
# [tool.uv]
# exclude-newer = "2026-08-15T00:00:00Z"
# ///
"""Read-only, structured evidence for the done closeout workflow."""

from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys
from typing import Any


SCHEMA_VERSION = 1
AUTHORITIES = ("full", "commit-push", "publish-branch", "verify", "local-only")


class CloseoutError(Exception):
    """An actionable input or environment error."""


def command(
    args: list[str], cwd: Path, *, input_text: str | None = None
) -> subprocess.CompletedProcess[str]:
    try:
        return subprocess.run(
            args,
            cwd=cwd,
            input=input_text,
            text=True,
            capture_output=True,
            check=False,
        )
    except FileNotFoundError as error:
        raise CloseoutError(f"required command is unavailable: {args[0]}") from error


def require_command(args: list[str], cwd: Path) -> str:
    result = command(args, cwd)
    if result.returncode != 0:
        detail = result.stderr.strip() or result.stdout.strip() or "command failed"
        raise CloseoutError(f"{' '.join(args)}: {detail}")
    return result.stdout.strip()


def sha256(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def git_output(repo: Path, *args: str) -> str:
    return require_command(["git", *args], repo)


def git_optional(repo: Path, *args: str) -> str | None:
    result = command(["git", *args], repo)
    value = result.stdout.strip()
    return value if result.returncode == 0 and value else None


def detect_backend(repo: Path) -> tuple[str, Path]:
    jj = command(["jj", "root", "--ignore-working-copy"], repo)
    if jj.returncode == 0 and jj.stdout.strip():
        return "jj", Path(jj.stdout.strip()).resolve()
    git = command(["git", "rev-parse", "--show-toplevel"], repo)
    if git.returncode == 0 and git.stdout.strip():
        return "git", Path(git.stdout.strip()).resolve()
    raise CloseoutError(f"not a Git or jj repository: {repo}")


def git_remote_and_default(repo: Path) -> tuple[str | None, str | None, str | None]:
    upstream = git_optional(
        repo, "rev-parse", "--abbrev-ref", "--symbolic-full-name", "@{upstream}"
    )
    if upstream and "/" in upstream:
        remote, branch = upstream.split("/", 1)
        return remote, branch, upstream

    remotes = git_optional(repo, "remote")
    remote = sorted(remotes.splitlines())[0] if remotes else None
    if remote:
        symbolic = git_optional(repo, "symbolic-ref", f"refs/remotes/{remote}/HEAD")
        prefix = f"refs/remotes/{remote}/"
        if symbolic and symbolic.startswith(prefix):
            branch = symbolic.removeprefix(prefix)
            return remote, branch, f"{remote}/{branch}"

    for branch in ("main", "master"):
        if git_optional(repo, "show-ref", "--verify", f"refs/heads/{branch}"):
            remote_ref = f"{remote}/{branch}" if remote else None
            return remote, branch, remote_ref
    return remote, None, None


def untracked_files(repo: Path) -> list[dict[str, str]]:
    raw = require_command(
        ["git", "ls-files", "--others", "--exclude-standard", "-z"], repo
    )
    entries: list[dict[str, str]] = []
    for relative in sorted(path for path in raw.split("\0") if path):
        path = repo / relative
        if path.is_symlink():
            digest = sha256(os.readlink(path).encode())
        elif path.is_file():
            digest = sha256(path.read_bytes())
        else:
            digest = sha256(b"")
        entries.append({"path": relative, "sha256": digest})
    return entries


def git_working_copy(repo: Path) -> dict[str, Any]:
    status = require_command(
        ["git", "status", "--porcelain=v1", "--untracked-files=all", "-z"], repo
    ).encode()
    staged = require_command(
        ["git", "diff", "--cached", "--binary", "--no-ext-diff"], repo
    )
    unstaged = require_command(["git", "diff", "--binary", "--no-ext-diff"], repo)
    untracked = untracked_files(repo)
    return {
        "clean": not status,
        "statusSha256": sha256(status),
        "stagedSha256": sha256(staged.encode()),
        "unstagedSha256": sha256(unstaged.encode()),
        "untracked": untracked,
    }


def load_receipt(path: str | None) -> dict[str, Any] | None:
    if not path:
        return None
    receipt_path = Path(path).expanduser().resolve()
    try:
        value = json.loads(receipt_path.read_text())
    except (OSError, json.JSONDecodeError) as error:
        raise CloseoutError(f"cannot read receipt {receipt_path}: {error}") from error
    if not isinstance(value, dict) or value.get("schemaVersion") not in (1, 2):
        raise CloseoutError(f"unsupported receipt schema: {value.get('schemaVersion')}")
    return {
        "path": str(receipt_path),
        "schemaVersion": value["schemaVersion"],
        "runId": value.get("runId"),
        "status": value.get("status"),
        "closeoutStatus": value.get("closeout", {}).get("status"),
    }


def git_snapshot(
    repo: Path, active_directory: Path, receipt: str | None
) -> dict[str, Any]:
    remote, default_branch, remote_ref = git_remote_and_default(repo)
    if remote and not default_branch:
        raise CloseoutError(
            f"cannot discover the default branch for remote {remote}; set its symbolic HEAD"
        )
    git_dir = Path(git_output(repo, "rev-parse", "--path-format=absolute", "--git-dir"))
    common_dir = Path(
        git_output(repo, "rev-parse", "--path-format=absolute", "--git-common-dir")
    )
    return {
        "schemaVersion": SCHEMA_VERSION,
        "backend": "git",
        "repositoryRoot": str(repo),
        "workspaceRoot": str(repo),
        "activeDirectory": str(active_directory),
        "vcs": {
            "head": git_output(repo, "rev-parse", "HEAD"),
            "branch": git_optional(repo, "branch", "--show-current"),
            "isWorktree": git_dir.resolve() != common_dir.resolve(),
        },
        "destination": {
            "remote": remote,
            "defaultBranch": default_branch,
            "remoteRef": remote_ref,
            "remoteTip": git_optional(repo, "rev-parse", remote_ref)
            if remote_ref
            else None,
        },
        "workingCopy": git_working_copy(repo),
        "receipt": load_receipt(receipt),
    }


def jj_snapshot(
    repo: Path, active_directory: Path, receipt: str | None
) -> dict[str, Any]:
    workspace = require_command(["jj", "workspace", "root"], repo)
    status = require_command(["jj", "status", "--color", "never"], repo)
    revision = require_command(
        [
            "jj",
            "log",
            "--ignore-working-copy",
            "-r",
            "@",
            "--no-graph",
            "-T",
            'change_id ++ "\\n" ++ commit_id ++ "\\n"',
        ],
        repo,
    ).splitlines()
    remotes = require_command(["jj", "git", "remote", "list"], repo)
    remote = sorted(line.split()[0] for line in remotes.splitlines() if line.split())
    trunk = require_command(
        [
            "jj",
            "log",
            "--ignore-working-copy",
            "-r",
            "trunk()",
            "--no-graph",
            "-T",
            'bookmarks ++ "\\n"',
        ],
        repo,
    )
    return {
        "schemaVersion": SCHEMA_VERSION,
        "backend": "jj",
        "repositoryRoot": str(repo),
        "workspaceRoot": str(Path(workspace).resolve()),
        "activeDirectory": str(active_directory),
        "vcs": {
            "changeId": revision[0] if revision else None,
            "commitId": revision[1] if len(revision) > 1 else None,
        },
        "destination": {"remote": remote[0] if remote else None, "trunk": trunk},
        "workingCopy": {
            "clean": "The working copy has no changes." in status,
            "statusSha256": sha256(status.encode()),
        },
        "receipt": load_receipt(receipt),
    }


def create_snapshot(
    repo_arg: str, active_arg: str | None, receipt: str | None
) -> dict[str, Any]:
    repo_input = Path(repo_arg).expanduser().resolve()
    if not repo_input.is_dir():
        raise CloseoutError(f"repository path is inaccessible: {repo_input}")
    backend, root = detect_backend(repo_input)
    active = (
        Path(active_arg).expanduser().resolve() if active_arg else Path.cwd().resolve()
    )
    if backend == "git":
        return git_snapshot(root, active, receipt)
    return jj_snapshot(root, active, receipt)


def read_snapshot(path: str) -> dict[str, Any]:
    snapshot_path = Path(path).expanduser().resolve()
    try:
        value = json.loads(snapshot_path.read_text())
    except (OSError, json.JSONDecodeError) as error:
        raise CloseoutError(f"cannot read snapshot {snapshot_path}: {error}") from error
    if not isinstance(value, dict) or value.get("schemaVersion") != SCHEMA_VERSION:
        raise CloseoutError(
            f"unsupported closeout snapshot schema: {value.get('schemaVersion')}"
        )
    return value


def git_commit(repo: Path, revision: str) -> str:
    return git_output(repo, "rev-parse", "--verify", f"{revision}^{{commit}}")


def patch_equivalent(repo: Path, remote_ref: str, revision: str) -> bool:
    parent = git_output(repo, "rev-parse", f"{revision}^")
    result = command(["git", "cherry", remote_ref, revision, parent], repo)
    return result.returncode == 0 and result.stdout.lstrip().startswith("-")


def range_patch_id(repo: Path, base: str, tip: str) -> str | None:
    diff = command(["git", "diff", "--binary", "--no-ext-diff", base, tip], repo)
    if diff.returncode != 0:
        return None
    result = command(["git", "patch-id", "--stable"], repo, input_text=diff.stdout)
    if result.returncode != 0 or not result.stdout.strip():
        return None
    return result.stdout.split()[0]


def classify_git(
    args: argparse.Namespace, snapshot: dict[str, Any]
) -> tuple[int, dict[str, Any]]:
    repo = Path(snapshot["repositoryRoot"])
    destination = snapshot.get("destination", {})
    remote_ref = destination.get("remoteRef")
    target_ref = remote_ref
    if not target_ref and args.authority == "local-only":
        target_ref = destination.get("defaultBranch")
    if not target_ref:
        raise CloseoutError("snapshot has no authoritative remote default ref")
    git_output(repo, "rev-parse", "--verify", f"{target_ref}^{{commit}}")
    revisions = [git_commit(repo, revision) for revision in args.task_revision]
    task_base = (
        git_commit(repo, args.task_base)
        if args.task_base
        else git_output(repo, "rev-parse", f"{revisions[0]}^")
    )

    classifications: list[dict[str, str]] = []
    unlanded: list[str] = []
    for revision in revisions:
        if (
            command(
                ["git", "merge-base", "--is-ancestor", revision, target_ref], repo
            ).returncode
            == 0
        ):
            evidence = "exact"
        elif patch_equivalent(repo, target_ref, revision):
            evidence = "patch-equivalent"
        else:
            evidence = "unlanded"
            unlanded.append(revision)
        classifications.append({"revision": revision, "evidence": evidence})

    if unlanded and args.landed_revision:
        landed = git_commit(repo, args.landed_revision)
        landed_parent = git_output(repo, "rev-parse", f"{landed}^")
        if range_patch_id(repo, task_base, revisions[-1]) == range_patch_id(
            repo, landed_parent, landed
        ):
            for item in classifications:
                if item["evidence"] == "unlanded":
                    item["evidence"] = "aggregate-patch-equivalent"
            unlanded = []

    local_only = git_output(
        repo, "rev-list", "--reverse", f"{target_ref}..HEAD"
    ).splitlines()
    allowed = set(revisions) | {
        git_commit(repo, item) for item in args.allow_local_revision
    }
    unrelated = [revision for revision in local_only if revision not in allowed]
    blockers: list[str] = []
    if unrelated:
        blockers.append("local default contains commits without publication authority")
    if args.authority == "verify" and unlanded:
        blockers.append("task revisions are not landed")

    payload = {
        "schemaVersion": SCHEMA_VERSION,
        "backend": "git",
        "status": "blocked" if blockers else "ready",
        "authority": args.authority,
        "destination": destination,
        "taskBase": task_base,
        "taskRevisions": classifications,
        "replayRevisions": unlanded,
        "unrelatedLocalCommits": unrelated,
        "blockers": blockers,
    }
    return (1 if blockers else 0), payload


def classify_jj(
    args: argparse.Namespace, snapshot: dict[str, Any]
) -> tuple[int, dict[str, Any]]:
    repo = Path(snapshot["repositoryRoot"])
    classifications: list[dict[str, str]] = []
    unlanded: list[str] = []
    for revision in args.task_revision:
        commit = require_command(
            [
                "jj",
                "log",
                "--ignore-working-copy",
                "-r",
                revision,
                "--no-graph",
                "-T",
                'commit_id ++ "\\n"',
            ],
            repo,
        )
        missing = require_command(
            [
                "jj",
                "log",
                "--ignore-working-copy",
                "-r",
                f"{revision} & ~::trunk()",
                "--no-graph",
                "-T",
                'commit_id ++ "\\n"',
            ],
            repo,
        )
        evidence = "unlanded" if missing else "exact"
        classifications.append(
            {"revision": revision, "commitId": commit, "evidence": evidence}
        )
        if missing:
            unlanded.append(revision)
    blockers = (
        ["task revisions are not landed"]
        if args.authority == "verify" and unlanded
        else []
    )
    payload = {
        "schemaVersion": SCHEMA_VERSION,
        "backend": "jj",
        "status": "blocked" if blockers else "ready",
        "authority": args.authority,
        "destination": snapshot.get("destination"),
        "taskRevisions": classifications,
        "replayRevisions": unlanded,
        "unrelatedLocalCommits": [],
        "blockers": blockers,
    }
    return (1 if blockers else 0), payload


def snapshot_command(args: argparse.Namespace) -> int:
    print(
        json.dumps(
            create_snapshot(args.repo, args.active_directory, args.receipt),
            sort_keys=True,
        )
    )
    return 0


def classify_command(args: argparse.Namespace) -> int:
    snapshot = read_snapshot(args.snapshot)
    if snapshot.get("backend") == "git":
        code, payload = classify_git(args, snapshot)
    elif snapshot.get("backend") == "jj":
        code, payload = classify_jj(args, snapshot)
    else:
        raise CloseoutError(
            f"unsupported backend in snapshot: {snapshot.get('backend')}"
        )
    print(json.dumps(payload, sort_keys=True))
    return code


def verify_preservation_command(args: argparse.Namespace) -> int:
    before = read_snapshot(args.snapshot)
    receipt = before.get("receipt") or {}
    current = create_snapshot(
        before["repositoryRoot"], before.get("activeDirectory"), receipt.get("path")
    )
    if before.get("workingCopy") != current.get("workingCopy"):
        print(
            "working-copy fingerprint changed; preserve the original task state and stop",
            file=sys.stderr,
        )
        return 1
    print(
        json.dumps(
            {
                "schemaVersion": SCHEMA_VERSION,
                "status": "preserved",
                "repositoryRoot": before["repositoryRoot"],
            },
            sort_keys=True,
        )
    )
    return 0


def parser() -> argparse.ArgumentParser:
    root = argparse.ArgumentParser(description=__doc__)
    sub = root.add_subparsers(dest="command", required=True)

    snapshot = sub.add_parser(
        "snapshot", help="capture secret-safe closeout state as JSON"
    )
    snapshot.add_argument("--repo", default=".")
    snapshot.add_argument("--active-directory")
    snapshot.add_argument("--receipt")
    snapshot.set_defaults(func=snapshot_command)

    classify = sub.add_parser(
        "classify", help="classify explicit task revisions without mutating VCS state"
    )
    classify.add_argument("--snapshot", required=True)
    classify.add_argument("--task-base")
    classify.add_argument("--task-revision", action="append", required=True)
    classify.add_argument("--landed-revision")
    classify.add_argument("--allow-local-revision", action="append", default=[])
    classify.add_argument("--authority", choices=AUTHORITIES, default="full")
    classify.set_defaults(func=classify_command)

    preservation = sub.add_parser(
        "verify-preservation", help="compare current dirt with a prior snapshot"
    )
    preservation.add_argument("--snapshot", required=True)
    preservation.set_defaults(func=verify_preservation_command)
    return root


def main() -> int:
    try:
        args = parser().parse_args()
        return args.func(args)
    except CloseoutError as error:
        print(str(error), file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
