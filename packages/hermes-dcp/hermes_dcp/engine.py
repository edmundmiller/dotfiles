"""DCP-style context engine for Hermes."""

from __future__ import annotations

import copy
import importlib
import json
import logging
from pathlib import Path
from typing import Any, TYPE_CHECKING

from hermes_dcp.config import DCPConfig, load_config

logger = logging.getLogger(__name__)


if TYPE_CHECKING:
    class _ContextEngineBase:
        last_prompt_tokens: int
        last_completion_tokens: int
        last_total_tokens: int
        threshold_tokens: int
        context_length: int
        compression_count: int
        threshold_percent: float
        protect_first_n: int
        protect_last_n: int

        def on_session_start(self, session_id: str, **kwargs: Any) -> None: ...
        def on_session_end(self, session_id: str, messages: list[dict[str, Any]]) -> None: ...
        def on_session_reset(self) -> None: ...
        def update_model(
            self,
            model: str,
            context_length: int,
            base_url: str = "",
            api_key: str = "",
            provider: str = "",
        ) -> None: ...

        def get_status(self) -> dict[str, Any]: ...
else:
    try:
        from agent.context_engine import ContextEngine as _ContextEngineBase  # type: ignore[reportMissingImports]
    except Exception:
        class _ContextEngineBase:
            last_prompt_tokens: int = 0
            last_completion_tokens: int = 0
            last_total_tokens: int = 0
            threshold_tokens: int = 0
            context_length: int = 0
            compression_count: int = 0
            threshold_percent: float = 0.75
            protect_first_n: int = 3
            protect_last_n: int = 6

            def on_session_start(self, session_id: str, **kwargs: Any) -> None:
                return None

            def on_session_end(self, session_id: str, messages: list[dict[str, Any]]) -> None:
                return None

            def on_session_reset(self) -> None:
                self.last_prompt_tokens = 0
                self.last_completion_tokens = 0
                self.last_total_tokens = 0
                self.compression_count = 0

            def update_model(
                self,
                model: str,
                context_length: int,
                base_url: str = "",
                api_key: str = "",
                provider: str = "",
            ) -> None:
                self.context_length = context_length
                self.threshold_tokens = int(context_length * self.threshold_percent)

            def get_status(self) -> dict[str, Any]:
                return {
                    "last_prompt_tokens": self.last_prompt_tokens,
                    "threshold_tokens": self.threshold_tokens,
                    "context_length": self.context_length,
                    "compression_count": self.compression_count,
                }


DCP_CONTEXT_SCHEMA = {
    "name": "dcp_context",
    "description": "Analyze current context and return prune/distill candidates.",
    "parameters": {
        "type": "object",
        "properties": {
            "max_candidates": {"type": "integer", "default": 20},
        },
        "required": [],
    },
}

DCP_PRUNE_SCHEMA = {
    "name": "dcp_prune",
    "description": "Generate or apply output-pruning placeholders for tool messages.",
    "parameters": {
        "type": "object",
        "properties": {
            "ids": {
                "type": "array",
                "items": {"type": "integer"},
                "description": "Message indices to prune (tool role messages).",
            },
            "apply": {
                "type": "boolean",
                "default": False,
                "description": "If true and live messages are provided by runtime, mutate in place.",
            },
        },
        "required": [],
    },
}

DCP_DISTILL_SCHEMA = {
    "name": "dcp_distill",
    "description": "Distill one large message into a concise carryover summary.",
    "parameters": {
        "type": "object",
        "properties": {
            "id": {"type": "integer", "description": "Message index to distill."},
            "summary": {
                "type": "string",
                "description": "Optional custom replacement summary.",
            },
            "apply": {"type": "boolean", "default": False},
        },
        "required": ["id"],
    },
}

DCP_COMPRESS_SCHEMA = {
    "name": "dcp_compress",
    "description": "Summarize a contiguous message range into one compact summary block.",
    "parameters": {
        "type": "object",
        "properties": {
            "start": {"type": "integer"},
            "end": {"type": "integer"},
            "topic": {"type": "string"},
            "apply": {"type": "boolean", "default": False},
        },
        "required": ["start", "end"],
    },
}


def _as_dict(value: Any) -> dict[str, Any]:
    return value if isinstance(value, dict) else {}


def _as_int(value: Any, default: int) -> int:
    if isinstance(value, bool):
        return default
    if isinstance(value, int):
        return value
    if isinstance(value, float):
        return int(value)
    if isinstance(value, str):
        text = value.strip()
        if not text:
            return default
        try:
            return int(text)
        except ValueError:
            return default
    return default


class DCPContextEngine(_ContextEngineBase):
    """Dynamic context pruning engine with Pi/OpenCode-inspired heuristics."""

    def __init__(self, config: DCPConfig | None = None):
        self._config = (config or DCPConfig()).normalize()
        self.threshold_percent = self._config.threshold
        self.protect_first_n = self._config.protect_first_n
        self.protect_last_n = self._config.protect_last_n
        self.last_prompt_tokens = 0
        self.last_completion_tokens = 0
        self.last_total_tokens = 0
        self.threshold_tokens = 0
        self.context_length = 0
        self.compression_count = 0
        self._session_id: str | None = None

    @property
    def name(self) -> str:
        return "dcp"

    def is_available(self) -> bool:
        return True

    def on_session_start(self, session_id: str, **kwargs: Any) -> None:
        self._session_id = session_id
        home_arg = kwargs.get("hermes_home")
        if isinstance(home_arg, (str, Path)):
            self._config = load_config(hermes_home=home_arg)
            self.threshold_percent = self._config.threshold
            self.protect_first_n = self._config.protect_first_n
            self.protect_last_n = self._config.protect_last_n
        if self.context_length:
            self.threshold_tokens = int(self.context_length * self.threshold_percent)

    def update_model(
        self,
        model: str,
        context_length: int,
        base_url: str = "",
        api_key: str = "",
        provider: str = "",
    ) -> None:
        self.context_length = context_length
        self.threshold_tokens = int(context_length * self.threshold_percent)

    def update_from_response(self, usage: dict[str, Any]) -> None:
        nested = _as_dict(usage.get("usage"))
        self.last_prompt_tokens = self._pick_token(
            usage.get("prompt_tokens"),
            usage.get("input_tokens"),
            nested.get("prompt_tokens"),
            nested.get("input_tokens"),
        )
        self.last_completion_tokens = self._pick_token(
            usage.get("completion_tokens"),
            usage.get("output_tokens"),
            nested.get("completion_tokens"),
            nested.get("output_tokens"),
        )
        self.last_total_tokens = self._pick_token(
            usage.get("total_tokens"),
            nested.get("total_tokens"),
            self.last_prompt_tokens + self.last_completion_tokens,
        )

    def should_compress(self, prompt_tokens: int | None = None) -> bool:
        tokens = prompt_tokens if prompt_tokens is not None else self.last_prompt_tokens
        return bool(self.threshold_tokens and tokens >= self.threshold_tokens)

    def should_compress_preflight(self, messages: list[dict[str, Any]]) -> bool:
        try:
            model_metadata = importlib.import_module("agent.model_metadata")
        except Exception:
            return False

        estimator = getattr(model_metadata, "estimate_messages_tokens_rough", None)
        if not callable(estimator):
            return False

        try:
            return self.should_compress(_as_int(estimator(messages), 0))
        except Exception:
            return False

    def has_content_to_compress(self, messages: list[dict[str, Any]]) -> bool:
        if len(messages) <= self.protect_first_n + self.protect_last_n:
            return False
        for idx, msg in enumerate(messages):
            if idx < self.protect_first_n or idx >= len(messages) - self.protect_last_n:
                continue
            if msg.get("role") == "tool" and len(str(msg.get("content") or "")) > self._config.max_tool_chars:
                return True
        return True

    def get_tool_schemas(self) -> list[dict[str, Any]]:
        return [
            DCP_CONTEXT_SCHEMA,
            DCP_PRUNE_SCHEMA,
            DCP_DISTILL_SCHEMA,
            DCP_COMPRESS_SCHEMA,
        ]

    def handle_tool_call(self, name: str, args: dict[str, Any], **kwargs: Any) -> str:
        maybe_messages = kwargs.get("messages")
        messages: list[dict[str, Any]] = maybe_messages if isinstance(maybe_messages, list) else []

        if name == "dcp_context":
            limit = max(1, _as_int(args.get("max_candidates"), 20))
            candidates = self._find_candidates(messages)[:limit]
            return json.dumps({"session": self._session_id, "candidates": candidates})

        if name == "dcp_prune":
            raw_ids = args.get("ids")
            ids: list[int] = []
            if isinstance(raw_ids, list):
                ids = [_as_int(i, -1) for i in raw_ids if _as_int(i, -1) >= 0]
            apply = bool(args.get("apply", False))
            if not ids:
                ids = [c["id"] for c in self._find_candidates(messages) if c.get("kind") == "prune"]
            updates: list[dict[str, Any]] = []
            for i in ids:
                if 0 <= i < len(messages) and messages[i].get("role") == "tool":
                    placeholder = self._pruned_placeholder(messages, i, reason="manual prune")
                    updates.append({"id": i, "placeholder": placeholder})
                    if apply:
                        messages[i]["content"] = placeholder
            return json.dumps({"updated": len(updates), "updates": updates, "applied": apply})

        if name == "dcp_distill":
            idx = _as_int(args.get("id"), -1)
            apply = bool(args.get("apply", False))
            summary = str(args.get("summary") or self._distill_message(messages, idx))
            if apply and 0 <= idx < len(messages):
                messages[idx]["content"] = summary
            return json.dumps({"id": idx, "summary": summary, "applied": apply})

        if name == "dcp_compress":
            start = _as_int(args.get("start"), 0)
            end = _as_int(args.get("end"), 0)
            apply = bool(args.get("apply", False))
            topic = str(args.get("topic") or "Completed work phase")
            summary = self._range_summary(messages, start, end, topic)
            if apply and messages and 0 <= start <= end < len(messages):
                replacement = {"role": "assistant", "content": summary}
                messages[start : end + 1] = [replacement]
            return json.dumps({"start": start, "end": end, "summary": summary, "applied": apply})

        return json.dumps({"error": f"Unknown context engine tool: {name}"})

    def compress(
        self,
        messages: list[dict[str, Any]],
        current_tokens: int | None = None,
        focus_topic: str | None = None,
    ) -> list[dict[str, Any]]:
        _ = current_tokens
        _ = focus_topic

        if not self._config.enabled:
            return list(messages)

        updated = copy.deepcopy(messages)
        if len(updated) <= self.protect_first_n + self.protect_last_n:
            return updated

        call_meta = self._collect_tool_meta(updated)
        latest_sig_index = self._latest_signature_results(updated, call_meta)
        turns_after = self._turns_after(updated)

        changed = False
        for idx, msg in enumerate(updated):
            if idx < self.protect_first_n or idx >= len(updated) - self.protect_last_n:
                continue
            if msg.get("role") != "tool":
                continue

            content = str(msg.get("content") or "")
            tool_call_id = str(msg.get("tool_call_id") or "")
            meta = _as_dict(call_meta.get(tool_call_id))
            tool_name = str(meta.get("name") or "unknown")
            signature = str(meta.get("signature") or "")
            age_turns = turns_after[idx]

            if self._config.dedupe and signature:
                latest_idx = latest_sig_index.get(signature)
                if latest_idx is not None and latest_idx != idx and age_turns >= 1:
                    msg["content"] = self._pruned_placeholder(updated, idx, reason="duplicate output")
                    changed = True
                    continue

            if len(content) > self._config.max_tool_chars and age_turns >= self._config.keep_recent_turns:
                msg["content"] = self._pruned_placeholder(updated, idx, reason="stale large output")
                changed = True

            if self._config.purge_errors and self._looks_error(msg) and age_turns >= self._config.error_turns:
                self._purge_tool_call_args(updated, tool_call_id, tool_name)
                changed = True

        if changed:
            self.compression_count += 1

        return updated

    def get_status(self) -> dict[str, Any]:
        status = super().get_status()
        status.update(
            {
                "engine": self.name,
                "session_id": self._session_id,
                "max_tool_chars": self._config.max_tool_chars,
                "keep_recent_turns": self._config.keep_recent_turns,
            }
        )
        return status

    def _pick_token(self, *values: Any) -> int:
        for v in values:
            if isinstance(v, bool):
                continue
            if isinstance(v, int):
                return v
            if isinstance(v, float):
                return int(v)
        return 0

    def _collect_tool_meta(self, messages: list[dict[str, Any]]) -> dict[str, dict[str, Any]]:
        meta: dict[str, dict[str, Any]] = {}
        for msg in messages:
            if msg.get("role") != "assistant":
                continue
            for call in msg.get("tool_calls") or []:
                fn = _as_dict(call.get("function"))
                args = str(fn.get("arguments") or "")
                name = str(fn.get("name") or "unknown")
                signature = f"{name}:{args[:500]}"
                meta[str(call.get("id") or "")] = {
                    "name": name,
                    "args": args,
                    "signature": signature,
                }
        return meta

    def _latest_signature_results(
        self,
        messages: list[dict[str, Any]],
        call_meta: dict[str, dict[str, Any]],
    ) -> dict[str, int]:
        out: dict[str, int] = {}
        for idx, msg in enumerate(messages):
            if msg.get("role") != "tool":
                continue
            call_id = str(msg.get("tool_call_id") or "")
            signature = str(_as_dict(call_meta.get(call_id)).get("signature") or "")
            if signature:
                out[signature] = idx
        return out

    def _turns_after(self, messages: list[dict[str, Any]]) -> list[int]:
        user_prefix: list[int] = []
        total = 0
        for m in messages:
            if m.get("role") == "user":
                total += 1
            user_prefix.append(total)
        return [max(0, total - seen) for seen in user_prefix]

    def _looks_error(self, msg: dict[str, Any]) -> bool:
        if bool(msg.get("is_error", False)):
            return True
        text = str(msg.get("content") or "")[:500].lower()
        return any(sig in text for sig in ["error", "traceback", "exception", "failed"])

    def _pruned_placeholder(self, messages: list[dict[str, Any]], idx: int, *, reason: str) -> str:
        call_id = str(messages[idx].get("tool_call_id") or "")
        tool_name = "unknown"
        for msg in messages:
            if msg.get("role") != "assistant":
                continue
            for call in msg.get("tool_calls") or []:
                if str(call.get("id") or "") == call_id:
                    tool_name = str(_as_dict(call.get("function")).get("name") or "unknown")
                    break
        original = str(messages[idx].get("content") or "")
        preview = self._brief(original)
        return (
            "[DCP PRUNED OUTPUT]\n"
            f"tool={tool_name}\n"
            f"reason={reason}\n"
            f"original_chars={len(original)}\n"
            f"preview={preview}"
        )

    def _brief(self, text: str) -> str:
        cleaned = " ".join(text.strip().split())
        if len(cleaned) <= self._config.distill_max_chars:
            return cleaned
        return f"{cleaned[: self._config.distill_max_chars - 3]}..."

    def _purge_tool_call_args(self, messages: list[dict[str, Any]], tool_call_id: str, tool_name: str) -> None:
        if not tool_call_id:
            return
        for msg in messages:
            if msg.get("role") != "assistant":
                continue
            calls = msg.get("tool_calls") or []
            for call in calls:
                if str(call.get("id") or "") != tool_call_id:
                    continue
                fn = _as_dict(call.get("function"))
                args_raw = str(fn.get("arguments") or "")
                keys: list[str] = []
                preview = self._brief(args_raw)
                try:
                    parsed = json.loads(args_raw)
                    if isinstance(parsed, dict):
                        keys = list(parsed.keys())[:10]
                        preview = self._brief(json.dumps(parsed, ensure_ascii=False))
                except Exception:
                    pass
                fn["arguments"] = json.dumps(
                    {
                        "_dcp_purged": True,
                        "tool": tool_name,
                        "keys": keys,
                        "preview": preview,
                    },
                    ensure_ascii=False,
                )
                call["function"] = fn

    def _find_candidates(self, messages: list[dict[str, Any]]) -> list[dict[str, Any]]:
        candidates: list[dict[str, Any]] = []
        for idx, msg in enumerate(messages):
            if msg.get("role") != "tool":
                continue
            content = str(msg.get("content") or "")
            if len(content) > self._config.max_tool_chars:
                candidates.append(
                    {
                        "id": idx,
                        "kind": "prune",
                        "chars": len(content),
                        "tool_call_id": msg.get("tool_call_id"),
                        "preview": self._brief(content),
                    }
                )
        return candidates

    def _distill_message(self, messages: list[dict[str, Any]], idx: int) -> str:
        if not (0 <= idx < len(messages)):
            return "[DCP DISTILL] invalid index"
        msg = messages[idx]
        content = str(msg.get("content") or "")
        return (
            "[DCP DISTILL]\n"
            f"role={msg.get('role', 'unknown')}\n"
            f"chars={len(content)}\n"
            f"summary={self._brief(content)}"
        )

    def _range_summary(
        self,
        messages: list[dict[str, Any]],
        start: int,
        end: int,
        topic: str,
    ) -> str:
        if not messages:
            return "[DCP RANGE SUMMARY]\nrange=empty\nhighlights:\n- (no messages)"

        if start > end:
            start, end = end, start
        start = max(0, start)
        end = min(len(messages) - 1, end)

        sample: list[str] = []
        tool_count = 0
        user_count = 0
        assistant_count = 0
        for msg in messages[start : end + 1]:
            role = str(msg.get("role") or "")
            if role == "tool":
                tool_count += 1
            elif role == "user":
                user_count += 1
            elif role == "assistant":
                assistant_count += 1

            text = str(msg.get("content") or "")
            if text and len(sample) < 4:
                sample.append(self._brief(text))

        bullets = "\n".join(f"- {line}" for line in sample) if sample else "- (no text sample)"
        return (
            "[DCP RANGE SUMMARY]\n"
            f"topic={topic}\n"
            f"range={start}-{end}\n"
            f"counts=user:{user_count},assistant:{assistant_count},tool:{tool_count}\n"
            "highlights:\n"
            f"{bullets}"
        )
