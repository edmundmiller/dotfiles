"""Tests for the format adapter: Hermes OpenAI -> VCC Anthropic JSONL."""

import json
import sys
import tempfile
from pathlib import Path

import pytest

from hermes_vcc.adapter import (
    convert_conversation,
    convert_message,
    records_to_jsonl,
    _extract_thinking,
    _is_compression_summary,
    _is_error_content,
    _parse_arguments,
)


# ---------------------------------------------------------------------------
# Unit tests for helper functions
# ---------------------------------------------------------------------------


class TestExtractThinking:
    def test_no_thinking(self):
        blocks, remaining = _extract_thinking("Hello world")
        assert blocks == []
        assert remaining == "Hello world"

    def test_single_think_tag(self):
        content = "<think>Some reasoning here</think>The answer is 42."
        blocks, remaining = _extract_thinking(content)
        assert len(blocks) == 1
        assert blocks[0]["type"] == "thinking"
        assert blocks[0]["thinking"] == "Some reasoning here"
        assert remaining == "The answer is 42."

    def test_scratchpad_tag(self):
        content = "<REASONING_SCRATCHPAD>Planning my approach</REASONING_SCRATCHPAD>Here's what I'll do."
        blocks, remaining = _extract_thinking(content)
        assert len(blocks) == 1
        assert blocks[0]["thinking"] == "Planning my approach"
        assert remaining == "Here's what I'll do."

    def test_empty_content(self):
        blocks, remaining = _extract_thinking("")
        assert blocks == []
        assert remaining == ""

    def test_none_content(self):
        blocks, remaining = _extract_thinking(None)
        assert blocks == []
        assert remaining == ""

    def test_multiline_thinking(self):
        content = "<think>Line 1\nLine 2\nLine 3</think>After."
        blocks, remaining = _extract_thinking(content)
        assert "Line 1\nLine 2\nLine 3" == blocks[0]["thinking"]

    def test_empty_think_tags(self):
        content = "<think></think>Just text."
        blocks, remaining = _extract_thinking(content)
        assert blocks == []
        assert remaining == "Just text."


class TestParseArguments:
    def test_valid_json(self):
        assert _parse_arguments('{"file_path": "/foo"}') == {"file_path": "/foo"}

    def test_empty_string(self):
        assert _parse_arguments("") == {}

    def test_malformed_json(self):
        result = _parse_arguments("{broken json")
        assert result == {"raw": "{broken json"}

    def test_non_dict_json(self):
        result = _parse_arguments('"just a string"')
        assert result == {"raw": '"just a string"'}

    def test_none(self):
        assert _parse_arguments(None) == {}


class TestIsErrorContent:
    def test_traceback(self):
        assert _is_error_content("Traceback (most recent call last):\n  File ...")

    def test_normal_content(self):
        assert not _is_error_content("File contents: hello world")

    def test_empty(self):
        assert not _is_error_content("")

    def test_error_keyword(self):
        assert _is_error_content("Error: permission denied")


class TestIsCompressionSummary:
    def test_matches_prefix(self):
        assert _is_compression_summary("[CONTEXT COMPACTION] Earlier turns...")

    def test_matches_legacy(self):
        assert _is_compression_summary("[CONTEXT SUMMARY]: The conversation...")

    def test_no_match(self):
        assert not _is_compression_summary("Just a normal message")

    def test_empty(self):
        assert not _is_compression_summary("")

    def test_none(self):
        assert not _is_compression_summary(None)


# ---------------------------------------------------------------------------
# convert_message tests
# ---------------------------------------------------------------------------


class TestConvertMessage:
    def test_user_message(self):
        msg = {"role": "user", "content": "Hello"}
        tool_map = {}
        records = convert_message(msg, tool_map)
        assert len(records) == 1
        rec = records[0]
        assert rec["type"] == "user"
        assert rec["message"]["content"] == "Hello"

    def test_system_message(self):
        msg = {"role": "system", "content": "You are helpful."}
        records = convert_message(msg, {})
        assert len(records) == 1
        assert records[0]["type"] == "system"
        assert records[0]["content"] == "You are helpful."

    def test_assistant_text_only(self):
        msg = {"role": "assistant", "content": "The answer is 42."}
        records = convert_message(msg, {})
        assert len(records) == 1
        rec = records[0]
        assert rec["type"] == "assistant"
        blocks = rec["message"]["content"]
        assert len(blocks) == 1
        assert blocks[0]["type"] == "text"
        assert blocks[0]["text"] == "The answer is 42."

    def test_assistant_with_thinking(self):
        msg = {"role": "assistant", "content": "<think>Hmm</think>The answer."}
        records = convert_message(msg, {})
        blocks = records[0]["message"]["content"]
        assert len(blocks) == 2
        assert blocks[0]["type"] == "thinking"
        assert blocks[0]["thinking"] == "Hmm"
        assert blocks[1]["type"] == "text"
        assert blocks[1]["text"] == "The answer."

    def test_assistant_with_tool_calls(self):
        msg = {
            "role": "assistant",
            "content": None,
            "tool_calls": [
                {
                    "id": "call_123",
                    "type": "function",
                    "function": {
                        "name": "Read",
                        "arguments": '{"file_path": "/foo/bar.py"}',
                    },
                }
            ],
        }
        tool_map = {}
        records = convert_message(msg, tool_map)
        assert len(records) == 1
        blocks = records[0]["message"]["content"]
        assert len(blocks) == 1
        block = blocks[0]
        assert block["type"] == "tool_use"
        assert block["name"] == "Read"
        assert block["id"] == "call_123"
        assert block["input"] == {"file_path": "/foo/bar.py"}
        # tool_name_map should be updated
        assert tool_map["call_123"] == "Read"

    def test_assistant_text_plus_tool_calls(self):
        msg = {
            "role": "assistant",
            "content": "Let me check that.",
            "tool_calls": [
                {
                    "id": "call_456",
                    "type": "function",
                    "function": {"name": "Bash", "arguments": '{"command": "ls"}'},
                }
            ],
        }
        tool_map = {}
        records = convert_message(msg, tool_map)
        blocks = records[0]["message"]["content"]
        assert len(blocks) == 2
        assert blocks[0]["type"] == "text"
        assert blocks[0]["text"] == "Let me check that."
        assert blocks[1]["type"] == "tool_use"
        assert blocks[1]["name"] == "Bash"

    def test_tool_result(self):
        msg = {
            "role": "tool",
            "content": "file contents here",
            "tool_call_id": "call_123",
        }
        records = convert_message(msg, {"call_123": "Read"})
        assert len(records) == 1
        rec = records[0]
        assert rec["type"] == "user"
        content = rec["message"]["content"]
        assert len(content) == 1
        assert content[0]["type"] == "tool_result"
        assert content[0]["tool_use_id"] == "call_123"
        assert content[0]["content"] == "file contents here"
        assert "is_error" not in content[0]

    def test_tool_result_error(self):
        msg = {
            "role": "tool",
            "content": "Error: file not found",
            "tool_call_id": "call_789",
        }
        records = convert_message(msg, {"call_789": "Read"})
        content = records[0]["message"]["content"]
        assert content[0]["is_error"] is True

    def test_tool_result_explicit_error(self):
        msg = {
            "role": "tool",
            "content": "something went wrong",
            "tool_call_id": "call_x",
            "is_error": True,
        }
        records = convert_message(msg, {})
        content = records[0]["message"]["content"]
        assert content[0]["is_error"] is True

    def test_compression_summary_inserts_boundary(self):
        msg = {
            "role": "user",
            "content": "[CONTEXT COMPACTION] Earlier turns in this conversation...",
        }
        records = convert_message(msg, {})
        assert len(records) == 2
        assert records[0]["type"] == "system"
        assert records[0]["subtype"] == "compact_boundary"
        assert records[1]["type"] == "user"
        assert records[1]["isCompactSummary"] is True

    def test_empty_assistant_content(self):
        """Assistant message with content=None and no tool_calls produces nothing."""
        msg = {"role": "assistant", "content": None}
        records = convert_message(msg, {})
        assert len(records) == 0

    def test_multi_tool_calls(self):
        msg = {
            "role": "assistant",
            "content": "Checking both.",
            "tool_calls": [
                {"id": "c1", "type": "function", "function": {"name": "Read", "arguments": '{"file_path": "a.txt"}'}},
                {"id": "c2", "type": "function", "function": {"name": "Read", "arguments": '{"file_path": "b.txt"}'}},
                {"id": "c3", "type": "function", "function": {"name": "Grep", "arguments": '{"pattern": "foo"}'}},
            ],
        }
        tool_map = {}
        records = convert_message(msg, tool_map)
        blocks = records[0]["message"]["content"]
        assert len(blocks) == 4  # 1 text + 3 tool_use
        assert blocks[0]["type"] == "text"
        assert all(b["type"] == "tool_use" for b in blocks[1:])
        assert tool_map == {"c1": "Read", "c2": "Read", "c3": "Grep"}

    def test_timestamp_propagation(self):
        msg = {"role": "user", "content": "Hi"}
        records = convert_message(msg, {}, timestamp="2026-03-31T12:00:00Z")
        assert records[0]["timestamp"] == "2026-03-31T12:00:00Z"

    def test_unknown_role(self):
        msg = {"role": "function", "content": "deprecated"}
        records = convert_message(msg, {})
        assert len(records) == 0


# ---------------------------------------------------------------------------
# convert_conversation tests
# ---------------------------------------------------------------------------


class TestConvertConversation:
    def test_basic_conversation(self, basic_conversation):
        records = convert_conversation(basic_conversation)
        # system + 2 user + 2 assistant = 5 records
        assert len(records) == 5
        assert records[0]["type"] == "system"
        assert records[1]["type"] == "user"
        assert records[2]["type"] == "assistant"
        assert records[3]["type"] == "user"
        assert records[4]["type"] == "assistant"

    def test_tool_conversation(self, tool_heavy_session):
        records = convert_conversation(tool_heavy_session)
        # Count tool_use blocks across assistant records
        tool_use_count = sum(
            1
            for r in records
            if r.get("type") == "assistant"
            for b in r.get("message", {}).get("content", [])
            if b.get("type") == "tool_use"
        )
        assert tool_use_count == 3  # Read, Edit, Grep

        # Count tool_result records
        tool_result_count = sum(
            1
            for r in records
            if r.get("type") == "user"
            for b in r.get("message", {}).get("content", [])
            if isinstance(b, dict) and b.get("type") == "tool_result"
        )
        assert tool_result_count == 3

    def test_thinking_conversation(self, thinking_session):
        records = convert_conversation(thinking_session)
        # Check thinking blocks exist
        thinking_blocks = []
        for r in records:
            if r.get("type") == "assistant":
                for b in r.get("message", {}).get("content", []):
                    if b.get("type") == "thinking":
                        thinking_blocks.append(b)
        assert len(thinking_blocks) == 2  # One <think>, one <REASONING_SCRATCHPAD>

    def test_compressed_session(self, compressed_session):
        records = convert_conversation(compressed_session)
        # Should have a compact_boundary record
        boundaries = [r for r in records if r.get("subtype") == "compact_boundary"]
        assert len(boundaries) == 1
        # Should have an isCompactSummary record
        summaries = [r for r in records if r.get("isCompactSummary")]
        assert len(summaries) == 1

    def test_multi_tool_message(self, multi_tool_message):
        records = convert_conversation(multi_tool_message)
        # The assistant message with 3 tool_calls should produce 1 record
        # with text + 3 tool_use blocks
        assistant_records = [r for r in records if r.get("type") == "assistant"]
        multi_tc_rec = assistant_records[0]
        blocks = multi_tc_rec["message"]["content"]
        tool_use_blocks = [b for b in blocks if b.get("type") == "tool_use"]
        assert len(tool_use_blocks) == 3

    def test_tool_name_resolution(self, tool_heavy_session):
        """Verify tool_use_id -> name mapping works across the conversation."""
        records = convert_conversation(tool_heavy_session)
        # Find tool_result records and check they have valid tool_use_ids
        for r in records:
            if r.get("type") == "user":
                content = r.get("message", {}).get("content", "")
                if isinstance(content, list):
                    for b in content:
                        if b.get("type") == "tool_result":
                            assert b["tool_use_id"], "tool_result must have tool_use_id"


# ---------------------------------------------------------------------------
# records_to_jsonl tests
# ---------------------------------------------------------------------------


class TestRecordsToJsonl:
    def test_serialization(self):
        records = [
            {"type": "user", "message": {"content": "hello"}},
            {"type": "assistant", "message": {"content": [{"type": "text", "text": "hi"}]}},
        ]
        jsonl = records_to_jsonl(records)
        lines = jsonl.strip().split("\n")
        assert len(lines) == 2
        assert json.loads(lines[0])["type"] == "user"
        assert json.loads(lines[1])["type"] == "assistant"

    def test_empty(self):
        assert records_to_jsonl([]) == ""


# ---------------------------------------------------------------------------
# VCC roundtrip test — validates adapter output against VCC's parser
# ---------------------------------------------------------------------------


class TestVCCRoundtrip:
    """Validate that adapter output can be parsed by VCC without errors."""

    def _compile_records(self, records, tmp_path, vcc_py_path):
        """Write records to JSONL and run VCC compile_pass."""
        jsonl_path = tmp_path / "test.jsonl"
        jsonl_path.write_text(records_to_jsonl(records))

        # Import VCC dynamically
        import importlib.util
        spec = importlib.util.spec_from_file_location("VCC", str(vcc_py_path))
        vcc = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(vcc)

        results = vcc.compile_pass(
            str(jsonl_path), str(tmp_path), truncate=128, truncate_user=256, quiet=True
        )
        return results

    def test_basic_roundtrip(self, basic_conversation, tmp_path, vcc_py_path):
        records = convert_conversation(basic_conversation)
        results = self._compile_records(records, tmp_path, vcc_py_path)
        assert len(results) >= 1
        # Verify .txt and .min.txt were created
        txt_files = list(tmp_path.glob("*.txt"))
        min_files = list(tmp_path.glob("*.min.txt"))
        assert len(txt_files) >= 1
        assert len(min_files) >= 1

    def test_tool_roundtrip(self, tool_heavy_session, tmp_path, vcc_py_path):
        records = convert_conversation(tool_heavy_session)
        results = self._compile_records(records, tmp_path, vcc_py_path)
        assert len(results) >= 1
        # Check the full transcript contains tool names
        txt_path = tmp_path / "test.txt"
        content = txt_path.read_text()
        assert "Read" in content
        assert "Edit" in content
        assert "Grep" in content

    def test_thinking_roundtrip(self, thinking_session, tmp_path, vcc_py_path):
        records = convert_conversation(thinking_session)
        results = self._compile_records(records, tmp_path, vcc_py_path)
        assert len(results) >= 1
        txt_path = tmp_path / "test.txt"
        content = txt_path.read_text()
        assert ">>>thinking" in content

    def test_compressed_roundtrip(self, compressed_session, tmp_path, vcc_py_path):
        records = convert_conversation(compressed_session)
        results = self._compile_records(records, tmp_path, vcc_py_path)
        # Should produce 2 chains (split at compact_boundary)
        # Chain 1: system message before boundary
        # Chain 2: compact summary + remaining messages
        txt_files = sorted(tmp_path.glob("test*.txt"))
        # Filter out .min.txt and .view.txt
        full_txts = [f for f in txt_files if ".min." not in f.name and ".view." not in f.name]
        assert len(full_txts) >= 1

    def test_multi_tool_roundtrip(self, multi_tool_message, tmp_path, vcc_py_path):
        records = convert_conversation(multi_tool_message)
        results = self._compile_records(records, tmp_path, vcc_py_path)
        assert len(results) >= 1
        txt_path = tmp_path / "test.txt"
        content = txt_path.read_text()
        # All 3 tool names should appear
        assert "Read" in content
        assert "Grep" in content
