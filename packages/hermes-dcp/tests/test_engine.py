from __future__ import annotations

import json

from hermes_dcp.config import DCPConfig
from hermes_dcp.engine import DCPContextEngine


def _messages():
    return [
        {"role": "system", "content": "You are helpful."},
        {"role": "user", "content": "Read the file."},
        {
            "role": "assistant",
            "content": None,
            "tool_calls": [
                {
                    "id": "call_1",
                    "type": "function",
                    "function": {"name": "read_file", "arguments": '{"path":"a.txt"}'},
                }
            ],
        },
        {"role": "tool", "tool_call_id": "call_1", "content": "A" * 4000},
        {"role": "assistant", "content": "Found stuff."},
        {"role": "user", "content": "Run the same read again."},
        {
            "role": "assistant",
            "content": None,
            "tool_calls": [
                {
                    "id": "call_2",
                    "type": "function",
                    "function": {"name": "read_file", "arguments": '{"path":"a.txt"}'},
                }
            ],
        },
        {"role": "tool", "tool_call_id": "call_2", "content": "A" * 3000},
        {"role": "assistant", "content": "Done."},
        {"role": "user", "content": "Now continue."},
    ]


def _engine() -> DCPContextEngine:
    cfg = DCPConfig(
        protect_first_n=2,
        protect_last_n=2,
        max_tool_chars=500,
        keep_recent_turns=1,
        dedupe=True,
    ).normalize()
    eng = DCPContextEngine(cfg)
    eng.on_session_start("sess")
    eng.update_model("x", 20000)
    return eng


def test_compress_prunes_and_dedupes_tool_outputs():
    eng = _engine()
    out = eng.compress(_messages(), current_tokens=18000)

    assert eng.compression_count == 1
    tool_contents = [m["content"] for m in out if m.get("role") == "tool"]
    assert any("DCP PRUNED OUTPUT" in c for c in tool_contents)


def test_dcp_context_tool_returns_candidates():
    eng = _engine()
    msgs = _messages()
    raw = eng.handle_tool_call("dcp_context", {}, messages=msgs)
    data = json.loads(raw)

    assert "candidates" in data
    assert data["candidates"]


def test_dcp_prune_tool_can_apply_in_place():
    eng = _engine()
    msgs = _messages()
    raw = eng.handle_tool_call("dcp_prune", {"ids": [3], "apply": True}, messages=msgs)
    data = json.loads(raw)

    assert data["applied"] is True
    assert "DCP PRUNED OUTPUT" in msgs[3]["content"]
