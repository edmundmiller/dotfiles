"""Convert Hermes OpenAI-format messages to VCC-compatible Anthropic JSONL records.

VCC expects records like:
  {"type": "user", "message": {"content": "text"}}
  {"type": "assistant", "message": {"content": [{type: "text", text: "..."}, ...], "id": "msg_123"}}
  {"type": "user", "message": {"content": [{type: "tool_result", tool_use_id: "...", content: "...", is_error: false}]}}
  {"type": "system", "content": "text"}
  {"type": "system", "subtype": "compact_boundary"}

Hermes uses OpenAI chat format:
  {"role": "user", "content": "text"}
  {"role": "assistant", "content": "text", "tool_calls": [{id, type, function: {name, arguments}}]}
  {"role": "tool", "content": "text", "tool_call_id": "..."}
  {"role": "system", "content": "text"}
"""

import json
import logging
import re
import uuid
from typing import Any

logger = logging.getLogger(__name__)

# Hermes compression summary prefix — triggers compact_boundary insertion.
SUMMARY_PREFIX = "[CONTEXT COMPACTION]"
LEGACY_SUMMARY_PREFIX = "[CONTEXT SUMMARY]:"

# Patterns for extracting thinking blocks from assistant content.
_THINK_RE = re.compile(r"<think>(.*?)</think>", re.DOTALL)
_SCRATCHPAD_RE = re.compile(
    r"<REASONING_SCRATCHPAD>(.*?)</REASONING_SCRATCHPAD>", re.DOTALL
)

# Heuristic error indicators in tool results.
_ERROR_INDICATORS = (
    "Error:", "error:", "Traceback", "traceback", "Exception:",
    "FAILED", "failed:", "command not found", "No such file",
    "Permission denied", "ModuleNotFoundError", "ImportError",
    "SyntaxError", "TypeError", "ValueError", "KeyError",
    "FileNotFoundError", "ConnectionError", "TimeoutError",
)


def _extract_thinking(content: str) -> tuple[list[dict], str]:
    """Extract <think> and <REASONING_SCRATCHPAD> blocks from content.

    Returns (thinking_blocks, remaining_text).
    """
    if not content:
        return [], ""

    thinking_blocks = []

    # Extract <REASONING_SCRATCHPAD> first (convert to think format)
    for match in _SCRATCHPAD_RE.finditer(content):
        text = match.group(1).strip()
        if text:
            thinking_blocks.append({"type": "thinking", "thinking": text})
    content = _SCRATCHPAD_RE.sub("", content)

    # Extract <think> blocks
    for match in _THINK_RE.finditer(content):
        text = match.group(1).strip()
        if text:
            thinking_blocks.append({"type": "thinking", "thinking": text})
    content = _THINK_RE.sub("", content)

    return thinking_blocks, content.strip()


def _parse_arguments(arguments: str) -> dict:
    """Parse tool call arguments JSON string, with fallback for malformed JSON."""
    if not arguments:
        return {}
    try:
        parsed = json.loads(arguments)
        if isinstance(parsed, dict):
            return parsed
        return {"raw": arguments}
    except (json.JSONDecodeError, TypeError):
        return {"raw": arguments}


def _is_error_content(content: str) -> bool:
    """Heuristic check if tool result content indicates an error."""
    if not content:
        return False
    # Check first 500 chars for error indicators
    head = content[:500]
    return any(indicator in head for indicator in _ERROR_INDICATORS)


def _is_compression_summary(content: str) -> bool:
    """Check if content is a Hermes compression summary."""
    if not content:
        return False
    return content.startswith(SUMMARY_PREFIX) or content.startswith(LEGACY_SUMMARY_PREFIX)


def _make_synthetic_id() -> str:
    """Generate a synthetic message ID for VCC chunk merging."""
    return f"msg_{uuid.uuid4().hex[:24]}"


def convert_message(
    msg: dict[str, Any],
    tool_name_map: dict[str, str],
    *,
    timestamp: str | None = None,
) -> list[dict[str, Any]]:
    """Convert a single Hermes OpenAI message to VCC JSONL record(s).

    Args:
        msg: Hermes message dict with role, content, optional tool_calls/tool_call_id.
        tool_name_map: Mapping of tool_call_id -> tool_name, built across the conversation.
        timestamp: Optional ISO timestamp to attach to records.

    Returns:
        List of VCC-compatible records (usually 1, but tool results may split).
    """
    role = msg.get("role", "")
    content = msg.get("content") or ""
    records: list[dict[str, Any]] = []

    if role == "system":
        rec: dict[str, Any] = {"type": "system", "content": content}
        if timestamp:
            rec["timestamp"] = timestamp
        records.append(rec)

    elif role == "user":
        # Check if this is a compression summary
        if _is_compression_summary(content):
            # Insert compact_boundary marker before the summary
            boundary: dict[str, Any] = {"type": "system", "subtype": "compact_boundary"}
            if timestamp:
                boundary["timestamp"] = timestamp
            records.append(boundary)

            # Emit the summary as a user message marked as compact summary
            rec = {
                "type": "user",
                "isCompactSummary": True,
                "message": {"content": content},
            }
            if timestamp:
                rec["timestamp"] = timestamp
            records.append(rec)
        else:
            rec = {"type": "user", "message": {"content": content}}
            if timestamp:
                rec["timestamp"] = timestamp
            records.append(rec)

    elif role == "assistant":
        content_blocks: list[dict[str, Any]] = []
        tool_calls = msg.get("tool_calls") or []

        # Extract thinking blocks from content text
        if content:
            thinking_blocks, remaining = _extract_thinking(content)
            content_blocks.extend(thinking_blocks)
            if remaining:
                content_blocks.append({"type": "text", "text": remaining})

        # Convert tool_calls to tool_use blocks
        for tc in tool_calls:
            fn = tc.get("function", {})
            tc_id = tc.get("id", _make_synthetic_id())
            name = fn.get("name", "unknown")
            arguments = fn.get("arguments", "")

            # Register in the tool name map for later tool_result resolution
            tool_name_map[tc_id] = name

            content_blocks.append({
                "type": "tool_use",
                "name": name,
                "id": tc_id,
                "input": _parse_arguments(arguments),
            })

        if content_blocks:
            rec = {
                "type": "assistant",
                "message": {
                    "content": content_blocks,
                    "id": _make_synthetic_id(),
                },
            }
            if timestamp:
                rec["timestamp"] = timestamp
            records.append(rec)

    elif role == "tool":
        # Tool result -> VCC expects this inside a "user" record
        # with content as a list containing a tool_result block
        tool_call_id = msg.get("tool_call_id", "")
        is_error = msg.get("is_error", _is_error_content(content))

        tool_result_block: dict[str, Any] = {
            "type": "tool_result",
            "tool_use_id": tool_call_id,
            "content": content,
        }
        if is_error:
            tool_result_block["is_error"] = True

        rec = {
            "type": "user",
            "message": {"content": [tool_result_block]},
        }
        if timestamp:
            rec["timestamp"] = timestamp
        records.append(rec)

    else:
        logger.warning("Unknown message role %r, skipping", role)

    return records


def convert_conversation(
    messages: list[dict[str, Any]],
    *,
    timestamps: list[str | None] | None = None,
) -> list[dict[str, Any]]:
    """Convert a full Hermes conversation to VCC JSONL records.

    Handles tool_call_id -> tool_name mapping across the conversation,
    synthesizes message IDs for VCC chunk merging, and inserts
    compact_boundary markers at compression summary points.

    Args:
        messages: List of Hermes OpenAI-format message dicts.
        timestamps: Optional parallel list of ISO timestamps per message.

    Returns:
        List of VCC-compatible JSONL records ready for VCC's lex() -> parse().
    """
    tool_name_map: dict[str, str] = {}
    records: list[dict[str, Any]] = []

    # First pass: build tool_name_map from all assistant tool_calls
    for msg in messages:
        if msg.get("role") == "assistant":
            for tc in msg.get("tool_calls") or []:
                fn = tc.get("function", {})
                tc_id = tc.get("id", "")
                if tc_id:
                    tool_name_map[tc_id] = fn.get("name", "unknown")

    # Second pass: convert all messages
    for i, msg in enumerate(messages):
        ts = timestamps[i] if timestamps and i < len(timestamps) else None
        converted = convert_message(msg, tool_name_map, timestamp=ts)
        records.extend(converted)

    return records


def records_to_jsonl(records: list[dict[str, Any]]) -> str:
    """Serialize VCC records to JSONL string (one JSON object per line)."""
    lines = []
    for rec in records:
        lines.append(json.dumps(rec, ensure_ascii=False))
    return "\n".join(lines) + "\n" if lines else ""
