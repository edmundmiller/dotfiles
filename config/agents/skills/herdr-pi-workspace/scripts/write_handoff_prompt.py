#!/usr/bin/env python3
"""Write a structured Pi handoff prompt.

Use this before start_pi_workspace.py when you want a consistent prompt shape
without hand-editing boilerplate.
"""

from __future__ import annotations

import argparse
from pathlib import Path


def bullet_section(title: str, items: list[str]) -> str:
    if not items:
        return ""
    lines = [f"{title}:"]
    lines.extend(f"- {item}" for item in items)
    return "\n".join(lines) + "\n\n"


def main() -> int:
    parser = argparse.ArgumentParser(description="Create a structured handoff prompt for a child Pi session.")
    parser.add_argument("--cwd", required=True, help="Repo/directory the child Pi should work in")
    parser.add_argument("--goal", required=True, help="Primary task for the child Pi")
    parser.add_argument("--output", required=True, help="Path to write the prompt")
    parser.add_argument("--context", action="append", default=[], help="Context bullet; repeatable")
    parser.add_argument("--read-first", action="append", default=[], help="File/path/doc to read first; repeatable")
    parser.add_argument("--guardrail", action="append", default=[], help="Safety constraint; repeatable")
    parser.add_argument("--done", action="append", default=[], help="Expected final-report item; repeatable")
    parser.add_argument("--validation", action="append", default=[], help="Validation command/check; repeatable")
    parser.add_argument(
        "--dirty-worktree-warning",
        action="store_true",
        help="Add a warning that unrelated dirty files may already exist",
    )
    args = parser.parse_args()

    guardrails = list(args.guardrail)
    if "Run `git status --short` before editing." not in guardrails:
        guardrails.insert(0, "Run `git status --short` before editing.")
    if args.dirty_worktree_warning:
        guardrails.append("There may be pre-existing unrelated dirty files; avoid touching them.")
    if "Do not commit secrets or tokens." not in guardrails:
        guardrails.append("Do not commit secrets or tokens.")

    done = args.done or [
        "Summarize files changed.",
        "Explain validation performed.",
        "List remaining risks/TODOs.",
    ]

    text = (
        f"You are working in `{args.cwd}`.\n\n"
        f"Goal: {args.goal}\n\n"
        + bullet_section("Context", args.context)
        + bullet_section("Read first", args.read_first)
        + bullet_section("Validation", args.validation)
        + bullet_section("Guardrails", guardrails)
        + bullet_section("When done", done)
    ).rstrip() + "\n"

    output = Path(args.output).expanduser()
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(text)
    print(output)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
