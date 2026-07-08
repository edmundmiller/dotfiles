#!/usr/bin/env python3
"""Commit accepted SkillOpt-Sleep skill proposals into dotfiles.

This intentionally supports one safe path: the generated learned skill. Broader
SkillOpt edits should stay staged for human review or PR mode.
"""
from __future__ import annotations

import argparse
import json
import os
import re
import subprocess
import sys
from pathlib import Path
from typing import Any

ALLOWED_TARGET = Path("skills/catalog/skillopt-sleep-learned/SKILL.md")
COMMIT_MESSAGE = "chore(skillopt): apply accepted sleep proposal"
PRIVATE_PATTERNS = {
    "email address": re.compile(r"\b[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}\b", re.I),
    "home path": re.compile(r"/Users/emiller\b"),
    "secret reference": re.compile(r"(?:op://|\b[A-Z0-9_]*(?:TOKEN|SECRET|PASSWORD|KEY)[A-Z0-9_]*\b)"),
    "session artifact": re.compile(r"\b(?:memory://|agent://|artifact://|\.omp/agent/sessions)"),
}



def run(cmd: list[str], cwd: Path, *, dry_run: bool = False) -> subprocess.CompletedProcess[str]:
    print("+", " ".join(cmd), file=sys.stderr)
    if dry_run:
        return subprocess.CompletedProcess(cmd, 0, "", "")
    return subprocess.run(cmd, cwd=cwd, text=True, capture_output=True, check=False)


def git_lines(repo: Path, args: list[str]) -> list[str]:
    result = subprocess.run(["git", *args], cwd=repo, text=True, capture_output=True, check=False)
    if result.returncode != 0:
        raise SystemExit(result.stderr.strip() or result.stdout.strip() or f"git {' '.join(args)} failed")
    return [line for line in result.stdout.splitlines() if line]


def latest_staging(root: Path) -> Path | None:
    candidates = [p for p in root.iterdir() if p.is_dir() and (p / "report.json").is_file()]
    return max(candidates, default=None, key=lambda p: p.name)


def read_json(path: Path) -> dict[str, Any]:
    with path.open(encoding="utf-8") as handle:
        value = json.load(handle)
    if not isinstance(value, dict):
        raise SystemExit(f"{path} did not contain a JSON object")
    return value


def validate_public_text(text: str) -> None:
    for label, pattern in PRIVATE_PATTERNS.items():
        if pattern.search(text):
            raise SystemExit(f"proposed skill contains private {label}; refusing to auto-commit")


def ensure_clean(repo: Path) -> None:
    dirty = git_lines(repo, ["status", "--porcelain"])
    if dirty:
        raise SystemExit("dotfiles worktree is dirty; refusing to auto-commit\n" + "\n".join(dirty))

def reset_clone(repo: Path) -> None:
    subprocess.run(["git", "reset", "--hard", "origin/main"], cwd=repo, text=True, capture_output=True, check=False)
    subprocess.run(["git", "clean", "-fd"], cwd=repo, text=True, capture_output=True, check=False)



def changed_paths(repo: Path) -> set[str]:
    paths: set[str] = set()
    for line in git_lines(repo, ["status", "--porcelain", "--untracked-files=all"]):
        paths.add(line[3:] if line.startswith("?? ") else line[3:])
    return paths


def ensure_repo(repo: Path, source_repo: Path, dry_run: bool) -> None:
    if (repo / ".git").exists():
        return
    remote = git_lines(source_repo, ["remote", "get-url", "origin"])[0]
    repo.parent.mkdir(parents=True, exist_ok=True)
    result = run(["git", "clone", remote, str(repo)], source_repo, dry_run=dry_run)
    if result.returncode != 0:
        raise SystemExit(result.stderr or result.stdout)


def write_marker(staging: Path, commit: str, dry_run: bool) -> None:
    marker = staging / "autocommit.json"
    payload = {"commit": commit, "target": str(ALLOWED_TARGET)}
    if dry_run:
        print(json.dumps({"would_write": str(marker), **payload}, indent=2))
    else:
        marker.write_text(json.dumps(payload, indent=2) + "\n", encoding="utf-8")


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--repo", default=str(Path.home() / ".skillopt-sleep" / "omp" / "dotfiles-autocommit"))
    parser.add_argument("--source-repo", default=str(Path.home() / ".config" / "dotfiles"))
    parser.add_argument("--staging-root", default=str(Path.home() / ".skillopt-sleep" / "omp" / "staging"))
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args(argv)

    repo = Path(args.repo).expanduser().resolve()
    source_repo = Path(args.source_repo).expanduser().resolve()
    staging_root = Path(args.staging_root).expanduser().resolve()
    staging = latest_staging(staging_root)
    if not staging:
        print("no staging reports found")
        return 0

    marker = staging / "autocommit.json"
    if marker.exists():
        print(f"already committed: {staging}")
        return 0

    report = read_json(staging / "report.json")
    project = Path(str(report.get("project") or "")).expanduser().resolve()
    if project != source_repo:
        print(f"latest staging is for {project}, not {source_repo}")
        return 0
    if not report.get("accepted"):
        print(f"latest staging not accepted: {staging}")
        return 0
    if not report.get("edits"):
        print(f"latest staging has no edits: {staging}")
        return 0

    proposed = staging / "proposed_SKILL.md"
    if not proposed.exists():
        print(f"no proposed skill file: {proposed}")
        return 0
    proposed_text = proposed.read_text(encoding="utf-8")
    if not proposed_text.strip():
        print(f"no proposed skill content: {proposed}")
        return 0
    validate_public_text(proposed_text)

    ensure_repo(repo, source_repo, args.dry_run)
    if args.dry_run and not (repo / ".git").exists():
        print(json.dumps({"would_clone": str(repo), "staging": str(staging)}, indent=2))
        return 0
    ensure_clean(repo)
    result = run(["git", "fetch", "origin", "main"], repo, dry_run=args.dry_run)
    if result.returncode != 0:
        raise SystemExit(result.stderr or result.stdout)
    current_branch = git_lines(repo, ["branch", "--show-current"])[0]
    if current_branch != "main":
        result = run(["git", "switch", "main"], repo, dry_run=args.dry_run)
        if result.returncode != 0:
            raise SystemExit(result.stderr or result.stdout)
    result = run(["git", "reset", "--hard", "origin/main"], repo, dry_run=args.dry_run)
    if result.returncode != 0:
        raise SystemExit(result.stderr or result.stdout)
    ensure_clean(repo)

    target = repo / ALLOWED_TARGET
    target.parent.mkdir(parents=True, exist_ok=True)
    if target.exists() and target.read_text(encoding="utf-8") == proposed_text:
        print(f"target already matches proposal: {ALLOWED_TARGET}")
        write_marker(staging, git_lines(repo, ["rev-parse", "HEAD"])[0], args.dry_run)
        return 0

    if args.dry_run:
        print(json.dumps({"staging": str(staging), "target": str(ALLOWED_TARGET), "would_commit": True}, indent=2))
        return 0

    try:
        target.write_text(proposed_text, encoding="utf-8")
        changed = changed_paths(repo)
        if changed != {str(ALLOWED_TARGET)}:
            raise SystemExit(f"unexpected changed paths: {sorted(changed)}")

        check_cmd = ["nix", "develop", "--command", "./bin/hey", "check", "--worktree", str(ALLOWED_TARGET)]
        result = run(check_cmd, repo)
        if result.returncode != 0:
            result = run(check_cmd, repo)
        if result.returncode != 0:
            raise SystemExit(result.stderr or result.stdout)

        changed = changed_paths(repo)
        if changed != {str(ALLOWED_TARGET)}:
            raise SystemExit(f"unexpected changed paths after checks: {sorted(changed)}")

        for cmd in (["git", "add", str(ALLOWED_TARGET)], ["git", "commit", "-m", COMMIT_MESSAGE], ["git", "push", "origin", "main"]):
            result = run(cmd, repo)
            if result.returncode != 0:
                raise SystemExit(result.stderr or result.stdout)
    except BaseException:
        reset_clone(repo)
        raise

    commit = git_lines(repo, ["rev-parse", "HEAD"])[0]
    write_marker(staging, commit, False)
    print(f"committed {commit} from {staging}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
