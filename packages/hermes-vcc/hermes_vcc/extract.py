"""
extract.py - Goal, preference, and file-ops extraction from normalized conversation blocks.

Ported from pi-vcc (goals.ts, preferences.ts, files.ts) with Hermes-specific tool names added.

NormalizedBlock dicts use a 'kind' key: user/assistant/tool_call/tool_result/thinking.
"""

import re
from typing import Any

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def _clip(text: str, max_len: int = 200) -> str:
    """Truncate text to max_len characters."""
    return text[:max_len]


def _non_empty_lines(text: str) -> list[str]:
    """Return non-empty, stripped lines from text."""
    return [line for line in text.splitlines() if line.strip()]


# ---------------------------------------------------------------------------
# Goals
# ---------------------------------------------------------------------------

_SCOPE_CHANGE_RE = re.compile(
    r"\b(instead|actually|change of plan|forget that|new task|switch to"
    r"|now I want|pivot|let'?s do|stop .* and)\b",
    re.IGNORECASE,
)

_TASK_RE = re.compile(
    r"\b(fix|implement|add|create|build|refactor|debug|investigate|update"
    r"|remove|delete|migrate|deploy|test|write|set up)\b",
    re.IGNORECASE,
)

_NOISE_SHORT_RE = re.compile(
    r"^(ok|yes|no|sure|yeah|yep|go|hi|hey|thx|thanks|ok\b.*|y|n|k)\s*[.!?]*$",
    re.IGNORECASE,
)


def _is_substantive_goal(text: str) -> bool:
    t = text.strip()
    return len(t) > 5 and not _NOISE_SHORT_RE.match(t)


def extract_goals(blocks: list[dict]) -> list[str]:
    """Extract up to 8 goal strings from a list of NormalizedBlock dicts."""
    goals: list[str] = []
    latest_scope_change: list[str] | None = None

    for b in blocks:
        if b.get("kind") != "user":
            continue
        text = b.get("text", "") or ""
        lines = [l for l in _non_empty_lines(text) if _is_substantive_goal(l)]
        if not lines:
            continue

        if not goals:
            goals.extend(lines[:3])
            continue

        if _SCOPE_CHANGE_RE.search(text):
            latest_scope_change = [_clip(l) for l in lines[:3]]
        elif _TASK_RE.search(text) and len(lines[0]) > 15:
            latest_scope_change = [_clip(l) for l in lines[:2]]

    if latest_scope_change:
        goals.append("[Scope change]")
        goals.extend(latest_scope_change)

    return goals[:8]


# ---------------------------------------------------------------------------
# Preferences
# ---------------------------------------------------------------------------

_PREF_PATTERNS = [
    re.compile(r"\bprefer\b", re.IGNORECASE),
    re.compile(r"\bdon'?t want\b", re.IGNORECASE),
    re.compile(r"\balways\b", re.IGNORECASE),
    re.compile(r"\bnever\b", re.IGNORECASE),
    re.compile(r"\bplease\s+(use|avoid|keep|make)\b", re.IGNORECASE),
    re.compile(r"\bstyle[:\s]", re.IGNORECASE),
    re.compile(r"\bformat[:\s]", re.IGNORECASE),
    re.compile(r"\blanguage[:\s]", re.IGNORECASE),
]


def extract_preferences(blocks: list[dict]) -> list[str]:
    """Extract up to 10 unique preference strings from user blocks."""
    prefs: list[str] = []
    seen: set[str] = set()

    for b in blocks:
        if b.get("kind") != "user":
            continue
        text = b.get("text", "") or ""
        for line in _non_empty_lines(text):
            trimmed = line.strip()
            if len(trimmed) < 5:
                continue
            if any(p.search(trimmed) for p in _PREF_PATTERNS):
                clipped = _clip(trimmed)
                if clipped not in seen:
                    seen.add(clipped)
                    prefs.append(clipped)

    return prefs[:10]


# ---------------------------------------------------------------------------
# File ops
# ---------------------------------------------------------------------------

_READ_TOOLS: set[str] = {
    "read_file", "cat", "open", "browser_navigate",
    # Hermes-specific
    "web_extract", "web_search",
}

_WRITE_TOOLS: set[str] = {
    "write_file", "patch", "edit_file", "sed", "awk", "str_replace_editor",
}

_CREATE_TOOLS: set[str] = {
    "touch", "mkdir", "new_file", "create_file",
}


def _path_from_args(args: dict[str, Any]) -> str | None:
    for key in ("path", "filename", "file", "url"):
        v = args.get(key)
        if isinstance(v, str) and v:
            return _clip(v)
    return None


def extract_file_ops(blocks: list[dict]) -> dict:
    """
    Extract file operations from tool_call blocks.

    Returns a dict with keys:
        read_files      - list of paths read
        modified_files  - list of paths written/patched
        created_files   - list of paths created
    """
    read_files: set[str] = set()
    modified_files: set[str] = set()
    created_files: set[str] = set()

    for b in blocks:
        if b.get("kind") != "tool_call":
            continue
        args = b.get("args") or {}
        path = _path_from_args(args)
        if not path:
            continue
        name = b.get("name", "")
        if name in _READ_TOOLS:
            read_files.add(path)
        elif name in _WRITE_TOOLS:
            modified_files.add(path)
        elif name in _CREATE_TOOLS:
            created_files.add(path)

    return {
        "read_files": list(read_files),
        "modified_files": list(modified_files),
        "created_files": list(created_files),
    }
