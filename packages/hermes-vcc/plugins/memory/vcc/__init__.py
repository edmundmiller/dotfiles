"""VCC MemoryProvider plugin for Hermes agent.

Lossless conversation archiving + structured compaction. No LLM calls.
"""

from __future__ import annotations

import json
import logging
from pathlib import Path
from typing import Any

try:
    from agent.memory_provider import MemoryProvider as _MemoryProviderBase
except ImportError:
    _MemoryProviderBase = object  # type: ignore[assignment,misc]

import json as _json

from hermes_vcc.archive import archive_before_compression
from hermes_vcc.compaction import (
    build_brief_transcript,
    build_outstanding_context,
    format_compaction,
    merge_compactions,
)
from hermes_vcc.config import VCCConfig, load_config
from hermes_vcc.extract import extract_file_ops, extract_goals, extract_preferences
from hermes_vcc.filter_noise import filter_noise
from hermes_vcc.recall import recall_search

logger = logging.getLogger(__name__)


# ---------------------------------------------------------------------------
# Internal: OpenAI messages -> NormalizedBlock dicts (kind-keyed)
# ---------------------------------------------------------------------------

def _to_normalized_blocks(messages: list[dict]) -> list[dict]:
    """Convert Hermes OpenAI-format messages to NormalizedBlock dicts.

    NormalizedBlock keys used by filter_noise / extract:
        kind:  user | assistant | tool_call | tool_result | thinking
        text:  str   (user / assistant)
        name:  str   (tool_call / tool_result)
        args:  dict  (tool_call)
        isError: bool (tool_result)
    """
    blocks: list[dict] = []
    for msg in messages:
        role = msg.get("role", "")
        content = msg.get("content") or ""

        if role == "user":
            blocks.append({"kind": "user", "text": content})

        elif role == "assistant":
            # Emit any text content first
            if content:
                blocks.append({"kind": "assistant", "text": content})
            # Emit tool calls as tool_call blocks
            for tc in msg.get("tool_calls") or []:
                fn = tc.get("function", {})
                name = fn.get("name", "unknown")
                try:
                    args = _json.loads(fn.get("arguments") or "{}")
                    if not isinstance(args, dict):
                        args = {}
                except Exception:  # noqa: BLE001
                    args = {}
                blocks.append({
                    "kind": "tool_call",
                    "name": name,
                    "id": tc.get("id", ""),
                    "args": args,
                })

        elif role == "tool":
            blocks.append({
                "kind": "tool_result",
                "name": "",  # name not available in OpenAI tool role
                "tool_call_id": msg.get("tool_call_id", ""),
                "text": content,
                "isError": bool(msg.get("is_error", False)),
            })

        elif role == "system":
            # system messages are not processed by filter_noise/extract
            pass

    return blocks


VCC_RECALL_SCHEMA = {
    "name": "vcc_recall",
    "description": (
        "Search conversation history across compaction boundaries. "
        "Uses hybrid search (BM25 + vector + reranking) when qmd is available, "
        "falling back to regex matching. Supports natural language queries."
    ),
    "parameters": {
        "type": "object",
        "properties": {
            "query": {
                "type": "string",
                "description": "Search query — natural language, keywords, or regex.",
            },
            "session_id": {
                "type": "string",
                "description": "Session ID to search (default: current session).",
            },
            "max_results": {
                "type": "integer",
                "default": 20,
            },
            "expand": {
                "type": "string",
                "description": (
                    "Retrieve full content for a docid (e.g. '#abc123') or "
                    "qmd file ref from a previous search result."
                ),
            },
        },
        "required": [],
    },
}


class VCCMemoryProvider(_MemoryProviderBase):
    """Hermes MemoryProvider that archives sessions via VCC."""

    # ------------------------------------------------------------------
    # Identity
    # ------------------------------------------------------------------

    @property
    def name(self) -> str:
        return "vcc"

    # ------------------------------------------------------------------
    # Lifecycle
    # ------------------------------------------------------------------

    def is_available(self) -> bool:
        """VCC needs no external API key — always available."""
        return True

    def initialize(self, session_id: str, **kwargs: Any) -> None:
        self._session_id = session_id
        hermes_home = kwargs.get("hermes_home")
        if hermes_home:
            self._archive_dir = Path(hermes_home) / "vcc_archives"
            self._hermes_home = Path(hermes_home)
        else:
            self._archive_dir = Path.home() / ".hermes" / "vcc_archives"
            self._hermes_home = Path.home() / ".hermes"
        self._config: VCCConfig = load_config()
        self._compression_cycle: int = 0
        self._last_compaction: str | None = None
        logger.debug(
            "VCCMemoryProvider initialised (session=%s, archive_dir=%s)",
            session_id,
            self._archive_dir,
        )

    # ------------------------------------------------------------------
    # Configuration schema
    # ------------------------------------------------------------------

    def get_config_schema(self) -> list[dict[str, Any]]:
        return [
            {
                "key": "archive_dir",
                "description": "Directory for session archives",
                "default": "~/.hermes/vcc_archives",
            },
            {
                "key": "retain_archives",
                "description": "Number of archive cycles to keep per session",
                "default": 10,
            },
        ]

    def save_config(self, values: dict[str, Any], hermes_home: str | Path) -> None:
        dest = Path(hermes_home) / "vcc.json"
        dest.parent.mkdir(parents=True, exist_ok=True)
        with dest.open("w", encoding="utf-8") as fh:
            json.dump(values, fh, indent=2)
        logger.debug("VCC config saved to %s", dest)

    # ------------------------------------------------------------------
    # Tool interface
    # ------------------------------------------------------------------

    def get_tool_schemas(self) -> list[dict[str, Any]]:
        return [VCC_RECALL_SCHEMA]

    def handle_tool_call(self, name: str, args: dict[str, Any]) -> str:
        if name == "vcc_recall":
            # Expand mode — retrieve full document by docid/file ref
            expand_ref = args.get("expand")
            if expand_ref:
                from hermes_vcc.recall import recall_expand

                content = recall_expand(expand_ref)
                if content is None:
                    return json.dumps({"error": f"could not retrieve {expand_ref}"})
                return json.dumps({"content": content})

            # Search mode
            query = args.get("query", "")
            if not query:
                return json.dumps({"error": "query or expand is required"})
            session_id = args.get("session_id") or self._session_id
            max_results = args.get("max_results", 20)
            matches = recall_search(query, session_id, self._archive_dir, max_results)
            return json.dumps({"results": matches})
        return json.dumps({"error": f"unknown tool: {name}"})

    # ------------------------------------------------------------------
    # Hooks
    # ------------------------------------------------------------------

    def on_pre_compress(self, messages: list[dict[str, Any]]) -> str | None:
        """Archive messages then build a structured compaction summary."""
        try:
            # 1. Lossless archive — must not raise
            try:
                archive_before_compression(
                    messages,
                    self._session_id,
                    self._archive_dir,
                    self._compression_cycle,
                )
            except Exception as exc:  # noqa: BLE001
                logger.warning("archive_before_compression raised unexpectedly: %s", exc)

            # 2. Convert to NormalizedBlock dicts
            blocks = _to_normalized_blocks(messages)

            # 3. Filter noise
            filtered = filter_noise(blocks)

            # 4. Extract signals
            goals = extract_goals(filtered)
            prefs = extract_preferences(filtered)
            file_ops = extract_file_ops(filtered)

            # 5. Build outstanding context
            outstanding = build_outstanding_context(filtered)

            # 6. Build brief transcript
            brief = build_brief_transcript(filtered)

            # 7. Format compaction string
            fresh = format_compaction(goals, file_ops, outstanding, prefs, brief)

            # 8. Merge with previous compaction
            if self._last_compaction:
                result = merge_compactions(self._last_compaction, fresh)
            else:
                result = fresh

            # 9. Store result
            self._last_compaction = result
            self._compression_cycle += 1

            # 10. Return for Hermes to use as compression summary
            return result

        except Exception as exc:  # noqa: BLE001
            logger.warning("on_pre_compress failed: %s", exc)
            return None

    def on_session_end(self, messages: list[dict[str, Any]]) -> None:
        """Final lossless archive flush at session close."""
        try:
            archive_before_compression(
                messages,
                self._session_id,
                self._archive_dir,
                self._compression_cycle + 1,
            )
        except Exception as exc:  # noqa: BLE001
            logger.warning("on_session_end archive failed: %s", exc)


# ------------------------------------------------------------------
# Plugin entry point
# ------------------------------------------------------------------

def register(ctx: Any) -> None:
    """Called by Hermes plugin loader to register this provider."""
    ctx.register_memory_provider(VCCMemoryProvider())
