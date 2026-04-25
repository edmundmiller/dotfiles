from __future__ import annotations

import importlib
import json
import unittest

from hermes_dcp.engine import DCPContextEngine

try:
    _agent_context_engine = importlib.import_module("agent.context_engine")
    ContextEngine = _agent_context_engine.ContextEngine
    _HERMES_CONTEXT_ENGINE_AVAILABLE = True
except Exception:
    ContextEngine = object
    _HERMES_CONTEXT_ENGINE_AVAILABLE = False


@unittest.skipUnless(
    _HERMES_CONTEXT_ENGINE_AVAILABLE,
    "Hermes runtime package not available in this environment",
)
def test_engine_satisfies_context_engine_abc() -> None:
    engine = DCPContextEngine(context_length=200000)
    assert isinstance(engine, ContextEngine)
    assert engine.name == "dcp"


def test_compress_returns_valid_messages() -> None:
    engine = DCPContextEngine(context_length=200000)
    msgs = [{"role": "user", "content": "hello"}]
    result = engine.compress(msgs)

    assert isinstance(result, list)
    assert all(isinstance(m, dict) and "role" in m for m in result)


def test_tools_return_json_payloads() -> None:
    engine = DCPContextEngine(context_length=200000)

    raw = engine.handle_tool_call("dcp_context", {}, messages=[])
    parsed = json.loads(raw)

    assert isinstance(parsed, dict)
    assert "candidates" in parsed
