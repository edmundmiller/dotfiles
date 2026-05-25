#!/usr/bin/env python3
"""Audit a repository's agent harness.

This script is intentionally dependency-free so an agent can copy/run it in an
unknown codebase without bootstrapping the target project first.
"""

from __future__ import annotations

import argparse
import json
import os
import re
import subprocess
import sys
from dataclasses import asdict, dataclass, field
from pathlib import Path
from typing import Iterable


@dataclass
class Finding:
    status: str
    title: str
    detail: str
    paths: list[str] = field(default_factory=list)
    suggestion: str | None = None


@dataclass
class Audit:
    repo: str
    harness_status: str
    languages: list[str]
    tools: dict[str, list[str]]
    findings: list[Finding]
    recommended_next_steps: list[str]


IGNORE_DIRS = {
    ".git",
    ".hg",
    ".svn",
    ".jj",
    "node_modules",
    ".venv",
    "venv",
    "dist",
    "build",
    "target",
    ".direnv",
    ".ruff_cache",
    ".pytest_cache",
    "__pycache__",
}

LANG_EXTS = {
    "python": {".py"},
    "javascript": {".js", ".jsx", ".mjs", ".cjs"},
    "typescript": {".ts", ".tsx", ".mts", ".cts"},
    "nix": {".nix"},
    "rust": {".rs"},
    "go": {".go"},
}

MANIFESTS = {
    "uv": ["uv.lock"],
    "python": ["pyproject.toml", "requirements.txt", "setup.py", "setup.cfg"],
    "pnpm": ["pnpm-lock.yaml", "pnpm-workspace.yaml"],
    "bun": ["bun.lock", "bun.lockb"],
    "node": ["package.json"],
    "mise": ["mise.toml", ".mise.toml", ".tool-versions"],
    "nix": ["flake.nix", "default.nix", "shell.nix"],
    "treefmt": ["treefmt.toml", "treefmt.nix"],
    "prek": ["prek.toml"],
    "pre-commit": [".pre-commit-config.yaml", ".pre-commit-config.yml"],
}


def rel(path: Path, root: Path) -> str:
    return path.relative_to(root).as_posix()


def exists_any(root: Path, names: Iterable[str]) -> list[str]:
    return [name for name in names if (root / name).exists()]


def walk_files(root: Path, max_files: int = 20_000) -> Iterable[Path]:
    count = 0
    for current, dirs, files in os.walk(root):
        dirs[:] = [d for d in dirs if d not in IGNORE_DIRS and not d.startswith(".cache")]
        base = Path(current)
        for name in files:
            count += 1
            if count > max_files:
                return
            yield base / name


def detect_languages(root: Path) -> list[str]:
    seen: set[str] = set()
    for path in walk_files(root):
        suffix = path.suffix.lower()
        for lang, exts in LANG_EXTS.items():
            if suffix in exts:
                seen.add(lang)
    return sorted(seen)


def detect_tools(root: Path) -> dict[str, list[str]]:
    tools: dict[str, list[str]] = {}
    for tool, names in MANIFESTS.items():
        found = exists_any(root, names)
        if found:
            tools[tool] = found
    return tools


def git_changed(root: Path) -> list[str]:
    try:
        proc = subprocess.run(
            ["git", "status", "--short"],
            cwd=root,
            check=False,
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.DEVNULL,
        )
    except OSError:
        return []
    changed: list[str] = []
    for line in proc.stdout.splitlines():
        if not line.strip():
            continue
        # Handles normal porcelain enough for a drift heuristic.
        changed.append(line[3:] if len(line) > 3 else line.strip())
    return changed


def find_skill_files(root: Path) -> list[Path]:
    skills_dir = root / ".agents" / "skills"
    if not skills_dir.exists():
        return []
    return sorted(skills_dir.glob("*/SKILL.md"))


def invalid_skill_dirs(root: Path) -> list[str]:
    skills_dir = root / ".agents" / "skills"
    if not skills_dir.exists():
        return []
    invalid: list[str] = []
    for child in sorted(p for p in skills_dir.iterdir() if p.is_dir()):
        if not (child / "SKILL.md").exists():
            invalid.append(rel(child, root))
    return invalid


def agents_files(root: Path) -> list[str]:
    found = [rel(p, root) for p in root.glob("**/AGENTS.md") if not any(part in IGNORE_DIRS for part in p.parts)]
    return sorted(found)


def file_contains_any(path: Path, needles: Iterable[str]) -> bool:
    try:
        text = path.read_text(errors="ignore")
    except OSError:
        return False
    low = text.lower()
    return any(n.lower() in low for n in needles)


def audit(root: Path) -> Audit:
    root = root.resolve()
    languages = detect_languages(root)
    tools = detect_tools(root)
    findings: list[Finding] = []

    root_agents = root / "AGENTS.md"
    all_agents = agents_files(root)
    if root_agents.exists():
        covers_commands = file_contains_any(root_agents, ["test", "lint", "format", "typecheck", "build", "check"])
        findings.append(
            Finding(
                "pass" if covers_commands else "warn",
                "Root AGENTS.md",
                "Root agent instructions exist." if covers_commands else "Root AGENTS.md exists but may not list common validation commands.",
                ["AGENTS.md"],
                None if covers_commands else "Add install, format, lint, typecheck, test, and generated-file/lock expectations.",
            )
        )
    else:
        findings.append(
            Finding(
                "fail",
                "Root AGENTS.md",
                "No top-level AGENTS.md found.",
                [],
                "Create AGENTS.md with repo purpose, layout, install command, checks, tests, and footguns.",
            )
        )

    if len(all_agents) > 1:
        findings.append(
            Finding("pass", "Scoped AGENTS.md", f"Found {len(all_agents) - 1} scoped AGENTS.md file(s).", all_agents[1:])
        )

    skill_files = [rel(p, root) for p in find_skill_files(root)]
    invalid_skills = invalid_skill_dirs(root)
    if skill_files:
        findings.append(Finding("pass", "Repo-local skills", f"Found {len(skill_files)} local skill(s).", skill_files))
    else:
        findings.append(
            Finding(
                "warn",
                "Repo-local skills",
                "No .agents/skills/<name>/SKILL.md files found.",
                [],
                "Only add repo-local skills for recurring repo-specific workflows.",
            )
        )
    if invalid_skills:
        findings.append(
            Finding(
                "fail",
                "Invalid skill directories",
                "Some .agents/skills children are missing SKILL.md.",
                invalid_skills,
                "Rename lowercase skill.md to SKILL.md or remove non-skill directories.",
            )
        )

    lock_paths = exists_any(root, ["skills-lock.json", "skills/flake.lock", "flake.lock"])
    skill_lock = [p for p in lock_paths if p in {"skills-lock.json", "skills/flake.lock"}]
    if skill_files and not skill_lock:
        findings.append(
            Finding(
                "warn",
                "Skills lock",
                "Local skills exist, but no obvious skills lock file was found.",
                lock_paths,
                "Add skills-lock.json or document why local skills are source-of-truth without a lock.",
            )
        )
    elif skill_files:
        findings.append(Finding("pass", "Skills lock", "Found an apparent skills lock/source pin.", skill_lock))

    changed = git_changed(root)
    skill_changed = [p for p in changed if p.startswith(".agents/skills/") or p.startswith("skills/catalog/")]
    lock_changed = [p for p in changed if p in {"skills-lock.json", "skills/flake.lock", "flake.lock"}]
    if skill_changed and not lock_changed:
        findings.append(
            Finding(
                "warn",
                "Changed skills without lock changes",
                "Git status shows skill changes but no obvious lock/source-pin changes.",
                skill_changed,
                "If skills are generated, copied, or remotely pinned, update the lock and parent lock before rebuilding.",
            )
        )

    if "prek" in tools:
        findings.append(Finding("pass", "prek.toml", "prek.toml exists; use it as the harness check hub.", tools["prek"]))
    elif "pre-commit" in tools:
        findings.append(
            Finding(
                "warn",
                "prek.toml",
                "No prek.toml found, but pre-commit config exists.",
                tools["pre-commit"],
                "If the user asked for prek, migrate harness-relevant checks carefully instead of duplicating hooks.",
            )
        )
    else:
        findings.append(
            Finding(
                "warn",
                "prek.toml",
                "No prek.toml or pre-commit config found.",
                [],
                "Consider adding prek.toml for agentic checks, lint/type/format wrappers, and lock drift guards.",
            )
        )

    if "python" in languages:
        py_paths = []
        for tool in ["uv", "python"]:
            py_paths.extend(tools.get(tool, []))
        missing = []
        if not any(file_contains_any(root / p, ["ruff"]) for p in py_paths if (root / p).exists()):
            missing.append("ruff")
        if not any(file_contains_any(root / p, ["ty"]) for p in py_paths if (root / p).exists()):
            missing.append("ty")
        findings.append(
            Finding(
                "pass" if not missing else "warn",
                "Python checks",
                "Python tooling mentions ruff and ty." if not missing else f"Python detected; missing obvious config/deps for: {', '.join(missing)}.",
                py_paths,
                None if not missing else "Prefer `uv run ruff format --check`, `uv run ruff check`, and `uv run ty check` when compatible.",
            )
        )

    if any(lang in languages for lang in ["javascript", "typescript"]):
        pkg = root / "package.json"
        mentions_ox = pkg.exists() and file_contains_any(pkg, ["oxlint", "oxfmt"])
        package_manager = "pnpm" if "pnpm" in tools else "bun" if "bun" in tools else "node" if "node" in tools else "unknown"
        findings.append(
            Finding(
                "pass" if mentions_ox else "warn",
                "JS/TS checks",
                "package.json mentions oxlint/oxfmt." if mentions_ox else f"JS/TS detected with package manager: {package_manager}; oxlint/oxfmt not obvious.",
                ["package.json"] if pkg.exists() else [],
                None if mentions_ox else "Prefer existing scripts, or add oxlint/oxfmt through the existing package manager.",
            )
        )

    if "nix" in languages or "nix" in tools:
        has_treefmt = "treefmt" in tools or any(file_contains_any(root / p, ["treefmt"]) for p in tools.get("nix", []))
        findings.append(
            Finding(
                "pass" if has_treefmt else "warn",
                "Nix/polyglot formatting",
                "treefmt appears configured." if has_treefmt else "Nix detected but treefmt was not obvious.",
                tools.get("treefmt", []) + tools.get("nix", []),
                None if has_treefmt else "If this is a mixed-language repo, consider treefmt; avoid introducing flakes/treefmt without approval.",
            )
        )

    if "mise" in tools:
        findings.append(Finding("pass", "mise", "mise/tool-version config found.", tools["mise"]))

    fail_count = sum(1 for f in findings if f.status == "fail")
    warn_count = sum(1 for f in findings if f.status == "warn")
    harness_status = "ready" if fail_count == 0 and warn_count <= 1 else "partial" if fail_count == 0 else "missing"

    recommended = [f.suggestion for f in findings if f.suggestion]
    return Audit(
        repo=str(root),
        harness_status=harness_status,
        languages=languages,
        tools=tools,
        findings=findings,
        recommended_next_steps=recommended[:8],
    )


def markdown(report: Audit) -> str:
    lines = [
        f"# Agent Harness Audit",
        "",
        f"- Repo: `{report.repo}`",
        f"- Harness status: `{report.harness_status}`",
        f"- Languages: {', '.join(report.languages) if report.languages else 'not detected'}",
        f"- Tool markers: {', '.join(sorted(report.tools)) if report.tools else 'not detected'}",
        "",
        "## Findings",
        "",
    ]
    icon = {"pass": "✅", "warn": "⚠️", "fail": "❌"}
    for finding in report.findings:
        lines.append(f"### {icon.get(finding.status, '•')} {finding.title}")
        lines.append(f"- Status: `{finding.status}`")
        lines.append(f"- Detail: {finding.detail}")
        if finding.paths:
            lines.append("- Paths: " + ", ".join(f"`{p}`" for p in finding.paths[:12]))
        if finding.suggestion:
            lines.append(f"- Suggestion: {finding.suggestion}")
        lines.append("")
    if report.recommended_next_steps:
        lines.extend(["## Recommended next steps", ""])
        for step in report.recommended_next_steps:
            lines.append(f"- {step}")
    return "\n".join(lines).rstrip() + "\n"


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Audit an agent-friendly repository harness.")
    parser.add_argument("repo", nargs="?", default=".", help="Repository path to audit. Defaults to cwd.")
    parser.add_argument("--json", action="store_true", help="Emit JSON instead of Markdown.")
    args = parser.parse_args(argv)

    root = Path(args.repo)
    if not root.exists() or not root.is_dir():
        print(f"error: repo path does not exist or is not a directory: {root}", file=sys.stderr)
        return 2

    report = audit(root)
    if args.json:
        print(json.dumps(asdict(report), indent=2, sort_keys=True))
    else:
        print(markdown(report), end="")
    return 1 if any(f.status == "fail" for f in report.findings) else 0


if __name__ == "__main__":
    raise SystemExit(main())
