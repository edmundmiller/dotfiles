#!/usr/bin/env python3
"""Validate portable agent-skill structure without third-party dependencies."""

from __future__ import annotations

import argparse
import ast
import json
import re
import sys
from dataclasses import asdict, dataclass
from pathlib import Path
from urllib.parse import unquote


MAX_DESCRIPTION_CHARACTERS = 1024
MAX_SKILL_LINES = 500
NAME_PATTERN = re.compile(r"^[a-z0-9]+(?:-[a-z0-9]+)*$")
FIELD_PATTERN = re.compile(r"^([A-Za-z][A-Za-z0-9_-]*):(?:[ \t]*(.*))?$")
LINK_PATTERN = re.compile(r"!?\[[^\]]*\]\(([^)]+)\)")
RUNTIME_SPECIFIC_MARKERS = (
    "allowed-tools:",
    "askuserquestion",
    "enterplanmode",
    "exitplanmode",
    "subagent tool",
    "`agent` tool",
    "`skill` tool",
)


@dataclass(frozen=True)
class Finding:
    path: str
    code: str
    message: str


def scalar(value: str) -> str:
    value = value.strip()
    if len(value) >= 2 and value[0] == value[-1] and value[0] in "\"'":
        try:
            parsed = ast.literal_eval(value)
        except (SyntaxError, ValueError):
            return value[1:-1]
        return parsed if isinstance(parsed, str) else str(parsed)
    return value


def parse_frontmatter(path: Path, lines: list[str]) -> tuple[dict[str, str], list[Finding]]:
    if not lines or lines[0].strip() != "---":
        return {}, [Finding(str(path), "frontmatter", "SKILL.md must start with YAML frontmatter")]

    try:
        end = next(index for index, line in enumerate(lines[1:], start=1) if line.strip() == "---")
    except StopIteration:
        return {}, [Finding(str(path), "frontmatter", "YAML frontmatter has no closing delimiter")]

    fields: dict[str, str] = {}
    index = 1
    while index < end:
        line = lines[index]
        match = FIELD_PATTERN.match(line)
        if not match:
            index += 1
            continue
        key, raw_value = match.groups()
        raw_value = raw_value or ""
        if raw_value in {">", ">-", ">+", "|", "|-", "|+"}:
            block: list[str] = []
            index += 1
            while index < end and (not lines[index].strip() or lines[index][:1].isspace()):
                block.append(lines[index].strip())
                index += 1
            separator = " " if raw_value.startswith(">") else "\n"
            fields[key] = separator.join(part for part in block if part).strip()
            continue
        fields[key] = scalar(raw_value)
        index += 1
    return fields, []


def local_reference(link: str) -> str | None:
    target = link.strip().split(maxsplit=1)[0].strip("<>")
    if not target or target.startswith(("#", "/")):
        return None
    if re.match(r"^[A-Za-z][A-Za-z0-9+.-]*:", target):
        return None
    target = unquote(target.split("#", 1)[0].split("?", 1)[0])
    return target or None


def validate_skill(path: Path) -> list[Finding]:
    findings: list[Finding] = []
    text = path.read_text(encoding="utf-8", errors="replace")
    lines = text.splitlines()
    fields, frontmatter_findings = parse_frontmatter(path, lines)
    findings.extend(frontmatter_findings)
    if frontmatter_findings:
        return findings

    name = fields.get("name", "").strip()
    description = fields.get("description", "").strip()
    if not name:
        findings.append(Finding(str(path), "name", "frontmatter requires a non-empty name"))
    elif not NAME_PATTERN.fullmatch(name):
        findings.append(Finding(str(path), "name", "name must use lowercase hyphenated words"))
    elif name != path.parent.name:
        findings.append(
            Finding(
                str(path),
                "name-directory",
                f"name {name!r} must match directory {path.parent.name!r}",
            )
        )

    if not description:
        findings.append(
            Finding(str(path), "description", "frontmatter requires a non-empty description")
        )
    elif len(description) > MAX_DESCRIPTION_CHARACTERS:
        findings.append(
            Finding(
                str(path),
                "description-length",
                f"description exceeds {MAX_DESCRIPTION_CHARACTERS} characters",
            )
        )

    if len(lines) > MAX_SKILL_LINES:
        findings.append(
            Finding(
                str(path),
                "line-count",
                f"SKILL.md has {len(lines)} lines; 500-line limit requires progressive disclosure",
            )
        )

    if fields.get("compatibility", "").strip().lower() == "portable":
        lowered = text.lower()
        for marker in RUNTIME_SPECIFIC_MARKERS:
            if marker in lowered:
                findings.append(
                    Finding(
                        str(path),
                        "portability",
                        f"portable skill uses runtime-specific tool name: {marker}",
                    )
                )

    for match in LINK_PATTERN.finditer(text):
        target = local_reference(match.group(1))
        if target is None:
            continue
        resolved = path.parent / target
        if not resolved.exists():
            findings.append(
                Finding(
                    str(path),
                    "local-reference",
                    f"missing local reference: {target}",
                )
            )
    return findings


def discover(paths: list[Path]) -> tuple[list[Path], list[Finding]]:
    skills: set[Path] = set()
    findings: list[Finding] = []
    for path in paths:
        if not path.exists():
            findings.append(Finding(str(path), "input", "path does not exist"))
        elif path.is_file():
            if path.name != "SKILL.md":
                findings.append(Finding(str(path), "input", "file must be named SKILL.md"))
            else:
                skills.add(path)
        elif (path / "SKILL.md").is_file():
            skills.add(path / "SKILL.md")
        else:
            skills.update(
                candidate
                for candidate in path.rglob("SKILL.md")
                if not {".git", "node_modules"}.intersection(candidate.parts)
            )
    return sorted(skills), findings


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--json", action="store_true", help="emit a machine-readable summary")
    parser.add_argument("paths", nargs="*", type=Path, default=[Path.cwd()])
    args = parser.parse_args(argv)

    skills, findings = discover(args.paths)
    for skill in skills:
        findings.extend(validate_skill(skill))
    findings.sort(key=lambda finding: (finding.path, finding.code, finding.message))

    if args.json:
        print(json.dumps({"checked": len(skills), "findings": [asdict(item) for item in findings]}))
    else:
        for finding in findings:
            print(f"{finding.path}: {finding.code}: {finding.message}")
        status = "PASS" if not findings else "FAIL"
        print(f"{status} skill-quality checked={len(skills)} findings={len(findings)}")
    return 1 if findings else 0


if __name__ == "__main__":
    sys.exit(main())
