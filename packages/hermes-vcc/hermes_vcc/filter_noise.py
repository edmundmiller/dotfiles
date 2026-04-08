"""filter_noise.py - Port of pi-vcc filter-noise.ts for Hermes VCC.

Removes low-signal blocks from a normalized conversation before it is
passed to a model: thinking blocks, calls/results for internal tooling,
and user messages that consist entirely of injected XML scaffolding or
well-known boilerplate strings.
"""

from __future__ import annotations

import re

NOISE_TOOLS: frozenset[str] = frozenset(
    [
        # pi-vcc original set
        "TodoWrite",
        "TodoRead",
        "ToolSearch",
        "WebSearch",
        "AskUser",
        "ExitSpecMode",
        "GenerateDroid",
        # Hermes-specific internal tools
        "memory",
        "send_message",
    ]
)

NOISE_STRINGS: tuple[str, ...] = (
    "Continue from where you left off.",
    "No response requested.",
    "IMPORTANT: TodoWrite was not called yet.",
)

# Matches self-contained XML wrapper elements that carry injected context
# rather than real conversation content.  The alternation includes the
# original pi-vcc tags plus the Hermes-specific <context-compression> tag.
XML_WRAPPER_RE: re.Pattern[str] = re.compile(
    r"<(system-reminder|ide_opened_file|command-message|context-window-usage|context-compression)"
    r"[^>]*>[\s\S]*?</\1>",
    re.MULTILINE,
)


def _is_noise_user_block(text: str) -> bool:
    trimmed = text.strip()
    if any(s in trimmed for s in NOISE_STRINGS):
        return True
    stripped = XML_WRAPPER_RE.sub("", trimmed).strip()
    return stripped == ""


def clean_user_text(text: str) -> str:
    """Strip XML wrapper elements from a user message and trim whitespace.

    Public so that other modules (e.g. summarisers) can reuse the logic.
    """
    return XML_WRAPPER_RE.sub("", text).strip()


def filter_noise(blocks: list[dict]) -> list[dict]:
    """Return a copy of *blocks* with noise entries removed.

    Dropped block categories:
    - thinking blocks (any)
    - tool_call / tool_result whose name is in NOISE_TOOLS
    - user blocks whose text is entirely boilerplate / XML wrappers
    """
    out: list[dict] = []
    for b in blocks:
        kind = b.get("kind")

        if kind == "thinking":
            continue

        if kind in ("tool_call", "tool_result") and b.get("name") in NOISE_TOOLS:
            continue

        if kind == "user":
            text = b.get("text", "")
            if _is_noise_user_block(text):
                continue
            cleaned = clean_user_text(text)
            if not cleaned:
                continue
            out.append({**b, "text": cleaned})
            continue

        out.append(b)

    return out
