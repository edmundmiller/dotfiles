"""
compaction.py - Structured compaction formatter for Hermes VCC.

Ported from pi-vcc format.ts, render-entries.ts, build-sections.ts, summarize.ts.
"""

import re
import json

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------

TOOL_TRUNCATE = 80
TEXT_TRUNCATE = 300
BRIEF_MAX_LINES = 120

CONTEXT_PATTERNS = [
    re.compile(r"\b(note that|keep in mind|remember|important|don'?t forget|fyi|heads up)\b", re.IGNORECASE),
    re.compile(r"\b(currently|right now|at the moment|as of now)\b", re.IGNORECASE),
    re.compile(r"\b(blocked|waiting|pending|depends on)\b", re.IGNORECASE),
]

HEADER_NAMES = ["Session Goal", "Files And Changes", "Outstanding Context", "User Preferences"]
SEPARATOR = "\n\n---\n\n"

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def _section(title: str, items: list[str]) -> str:
    if not items:
        return ""
    body = "\n".join(f"- {i}" for i in items)
    return f"[{title}]\n{body}"


def _non_empty_lines(text: str) -> list[str]:
    return [l for l in text.splitlines() if l.strip()]


def _clip(text: str, max_len: int = 200) -> str:
    return text[:max_len]


# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

def build_brief_transcript(blocks: list[dict], text_truncate: int = TEXT_TRUNCATE, tool_truncate: int = TOOL_TRUNCATE) -> str:
    """Render a concise transcript from normalized blocks."""
    lines: list[str] = []
    idx = 0
    for b in blocks:
        kind = b.get("kind")
        if kind == "user":
            text = (b.get("text") or "")
            preview = text[:text_truncate]
            suffix = "..." if len(text) > text_truncate else ""
            lines.append(f"U: {preview}{suffix}")
        elif kind == "assistant":
            text = (b.get("text") or "")
            preview = text[:text_truncate]
            suffix = "..." if len(text) > text_truncate else ""
            lines.append(f"A: {preview}{suffix}")
        elif kind == "tool_call":
            idx += 1
            args = b.get("args") or {}
            arg_str = ", ".join(
                f"{k}={json.dumps(v)[:40]}"
                for k, v in args.items()
            )
            lines.append(f"{b.get('name', '')}({arg_str}) (#{idx})")
        elif kind == "tool_result":
            text = (b.get("text") or "")
            preview = text[:tool_truncate]
            suffix = "..." if len(text) > tool_truncate else ""
            prefix = "ERR" if b.get("isError") else "OK"
            lines.append(f"  -> {prefix}: {preview}{suffix} (#{idx})")
    return "\n".join(lines)


def build_outstanding_context(blocks: list[dict]) -> list[str]:
    """Extract notable context lines from user/assistant blocks."""
    items: list[str] = []
    for b in blocks:
        if b.get("kind") not in ("user", "assistant"):
            continue
        text = b.get("text") or ""
        for line in _non_empty_lines(text):
            if any(p.search(line) for p in CONTEXT_PATTERNS) and 10 < len(line) < 300:
                items.append(_clip(line.strip(), 200))
    return list(dict.fromkeys(items))[:8]


def cap_brief(text: str, max_lines: int = BRIEF_MAX_LINES) -> str:
    """Cap brief transcript to max_lines, keeping the tail."""
    lines = text.split("\n")
    if len(lines) <= max_lines:
        return text
    omitted = len(lines) - max_lines
    kept = lines[-max_lines:]
    first_header = next((i for i, l in enumerate(kept) if re.match(r"^\[.+\]", l)), -1)
    clean = kept[first_header:] if first_header > 0 else kept
    return f"...({omitted} earlier lines omitted)\n\n{chr(10).join(clean)}"


def format_compaction(
    goals: list[str],
    file_ops: dict,
    outstanding: list[str],
    prefs: list[str],
    brief: str,
) -> str:
    """
    Format a full compaction summary string.

    file_ops: dict with keys read_files, modified_files, created_files.
    """
    files_and_changes: list[str] = []
    for path in file_ops.get("modified_files", []):
        files_and_changes.append(f"{path} (modified)")
    for path in file_ops.get("created_files", []):
        files_and_changes.append(f"{path} (created)")
    for path in file_ops.get("read_files", []):
        files_and_changes.append(f"{path} (read)")

    header_parts = [
        _section("Session Goal", goals),
        _section("Files And Changes", files_and_changes),
        _section("Outstanding Context", outstanding),
        _section("User Preferences", prefs),
    ]
    header_parts = [p for p in header_parts if p]

    parts: list[str] = []
    if header_parts:
        parts.append("\n\n".join(header_parts))
    if brief:
        parts.append(cap_brief(brief))
    return SEPARATOR.join(parts)


def _parse_header_section(text: str, header: str) -> str | None:
    """Extract the body of a named section from a compaction string."""
    pattern = re.compile(
        rf"^\[{re.escape(header)}\]\n((?:- .+\n?)*)",
        re.MULTILINE,
    )
    m = pattern.search(text)
    if not m:
        return None
    return m.group(0).rstrip()


def _merge_header_section(header: str, prev_body: str | None, fresh_body: str | None) -> str:
    """Merge two header section strings per pi-vcc rules."""
    if header == "Outstanding Context":
        return fresh_body or ""
    if not prev_body:
        return fresh_body or ""
    if not fresh_body:
        return prev_body or ""
    prev_lines = [l for l in prev_body.split("\n") if l.startswith("- ")]
    fresh_lines = [l for l in fresh_body.split("\n") if l.startswith("- ")]
    combined = list(dict.fromkeys(prev_lines + fresh_lines))
    if not combined:
        return ""
    return f"[{header}]\n" + "\n".join(combined)


def merge_compactions(prev: str, fresh: str) -> str:
    """
    Merge a previous compaction summary with a fresh one.

    - Headers: deduplicated union except Outstanding Context which uses fresh only.
    - Brief transcript: prev + newline + fresh, then capped at BRIEF_MAX_LINES.
    """
    def split_parts(text: str):
        if SEPARATOR in text:
            idx = text.rfind(SEPARATOR)
            return text[:idx], text[idx + len(SEPARATOR):]
        # No separator - check if it looks like a header block or just brief
        if re.search(r"^\[.+\]", text, re.MULTILINE):
            return text, ""
        return "", text

    prev_headers, prev_brief = split_parts(prev)
    fresh_headers, fresh_brief = split_parts(fresh)

    merged_sections: list[str] = []
    for header in HEADER_NAMES:
        prev_sec = _parse_header_section(prev_headers, header)
        fresh_sec = _parse_header_section(fresh_headers, header)
        merged = _merge_header_section(header, prev_sec, fresh_sec)
        if merged:
            merged_sections.append(merged)

    combined_brief_raw = "\n".join(filter(None, [prev_brief, fresh_brief]))
    capped_brief = cap_brief(combined_brief_raw) if combined_brief_raw else ""

    parts: list[str] = []
    if merged_sections:
        parts.append("\n\n".join(merged_sections))
    if capped_brief:
        parts.append(capped_brief)
    return SEPARATOR.join(parts)
