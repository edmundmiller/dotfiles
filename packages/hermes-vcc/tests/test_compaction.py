"""Tests for hermes_vcc/compaction.py"""

import pytest
from hermes_vcc.compaction import (
    build_brief_transcript,
    build_outstanding_context,
    cap_brief,
    format_compaction,
    merge_compactions,
    SEPARATOR,
)


# ---------------------------------------------------------------------------
# format_compaction
# ---------------------------------------------------------------------------

def test_format_compaction_basic_structure():
    goals = ["Fix the bug"]
    file_ops = {
        "modified_files": ["foo.py"],
        "created_files": ["bar.py"],
        "read_files": ["README.md"],
    }
    outstanding = ["Note that the API is rate limited"]
    prefs = ["prefer snake_case"]
    brief = "U: hello\nA: hi"

    result = format_compaction(goals, file_ops, outstanding, prefs, brief)

    assert "[Session Goal]" in result
    assert "- Fix the bug" in result
    assert "[Files And Changes]" in result
    assert "- foo.py (modified)" in result
    assert "- bar.py (created)" in result
    assert "- README.md (read)" in result
    assert "[Outstanding Context]" in result
    assert "[User Preferences]" in result
    assert "- prefer snake_case" in result
    assert SEPARATOR in result
    assert "U: hello" in result


def test_format_compaction_empty_brief():
    result = format_compaction(["Do thing"], {}, [], [], "")
    assert SEPARATOR not in result
    assert "[Session Goal]" in result


def test_format_compaction_all_empty():
    result = format_compaction([], {}, [], [], "")
    assert result == ""


def test_format_compaction_file_ops_ordering():
    file_ops = {
        "modified_files": ["a.py"],
        "created_files": ["b.py"],
        "read_files": ["c.py"],
    }
    result = format_compaction([], file_ops, [], [], "")
    lines = result.split("\n")
    # modified before created before read
    idx_a = next(i for i, l in enumerate(lines) if "a.py" in l)
    idx_b = next(i for i, l in enumerate(lines) if "b.py" in l)
    idx_c = next(i for i, l in enumerate(lines) if "c.py" in l)
    assert idx_a < idx_b < idx_c


# ---------------------------------------------------------------------------
# cap_brief
# ---------------------------------------------------------------------------

def test_cap_brief_no_truncation():
    text = "\n".join(f"line {i}" for i in range(50))
    assert cap_brief(text) == text


def test_cap_brief_truncates_to_max_lines():
    text = "\n".join(f"line {i}" for i in range(200))
    result = cap_brief(text, max_lines=120)
    result_lines = result.split("\n")
    # First line is the omission notice
    assert "omitted" in result_lines[0]
    omitted = 200 - 120
    assert str(omitted) in result_lines[0]


def test_cap_brief_prefers_header_start():
    # If there's a [Section] header in the kept tail, trim to it
    lines = [f"line {i}" for i in range(10)]
    lines += ["garbage1", "garbage2", "[Header]", "real content"]
    text = "\n".join(lines)
    # max_lines=8 means we keep last 8 lines: garbage1, garbage2, [Header], real content, plus 4 more
    result = cap_brief(text, max_lines=8)
    assert "[Header]" in result


def test_cap_brief_exact_boundary():
    text = "\n".join(f"x" for _ in range(120))
    assert cap_brief(text) == text


# ---------------------------------------------------------------------------
# build_brief_transcript
# ---------------------------------------------------------------------------

def test_build_brief_transcript_user_assistant():
    blocks = [
        {"kind": "user", "text": "hello"},
        {"kind": "assistant", "text": "world"},
    ]
    result = build_brief_transcript(blocks)
    assert result == "U: hello\nA: world"


def test_build_brief_transcript_truncation():
    long = "x" * 400
    blocks = [{"kind": "user", "text": long}]
    result = build_brief_transcript(blocks, text_truncate=300)
    assert result.endswith("...")
    assert len(result) < 320


def test_build_brief_transcript_tool_call_result():
    blocks = [
        {"kind": "tool_call", "name": "read_file", "args": {"path": "/foo/bar.py"}},
        {"kind": "tool_result", "text": "file contents here", "isError": False},
    ]
    result = build_brief_transcript(blocks)
    assert "read_file" in result
    assert "(#1)" in result
    assert "-> OK:" in result


def test_build_brief_transcript_tool_result_error():
    blocks = [
        {"kind": "tool_call", "name": "write_file", "args": {}},
        {"kind": "tool_result", "text": "permission denied", "isError": True},
    ]
    result = build_brief_transcript(blocks)
    assert "-> ERR:" in result


# ---------------------------------------------------------------------------
# build_outstanding_context
# ---------------------------------------------------------------------------

def test_build_outstanding_context_finds_patterns():
    blocks = [
        {"kind": "user", "text": "Note that the API key expires tomorrow"},
        {"kind": "assistant", "text": "Keep in mind the rate limit is 100/min"},
        {"kind": "tool_call", "name": "x", "args": {}},
    ]
    result = build_outstanding_context(blocks)
    assert len(result) == 2
    assert any("API key" in r for r in result)
    assert any("rate limit" in r for r in result)


def test_build_outstanding_context_deduplicates():
    line = "Note that we are blocked on the deploy"
    blocks = [
        {"kind": "user", "text": line},
        {"kind": "assistant", "text": line},
    ]
    result = build_outstanding_context(blocks)
    assert result.count(line) == 1


def test_build_outstanding_context_max_8():
    blocks = [
        {"kind": "user", "text": "\n".join(f"Note that item {i} is important" for i in range(20))}
    ]
    result = build_outstanding_context(blocks)
    assert len(result) <= 8


# ---------------------------------------------------------------------------
# merge_compactions
# ---------------------------------------------------------------------------

def test_merge_compactions_deduplicates_goals():
    prev = format_compaction(["Fix bug"], {}, [], [], "")
    fresh = format_compaction(["Fix bug", "Add tests"], {}, [], [], "")
    merged = merge_compactions(prev, fresh)
    assert merged.count("- Fix bug") == 1
    assert "- Add tests" in merged


def test_merge_compactions_outstanding_context_replaced():
    prev = format_compaction([], {}, ["Note that old context"], [], "")
    fresh = format_compaction([], {}, ["Note that new context"], [], "")
    merged = merge_compactions(prev, fresh)
    assert "old context" not in merged
    assert "new context" in merged


def test_merge_compactions_brief_concatenated():
    prev = format_compaction([], {}, [], [], "U: first")
    fresh = format_compaction([], {}, [], [], "U: second")
    merged = merge_compactions(prev, fresh)
    assert "U: first" in merged
    assert "U: second" in merged


def test_merge_compactions_brief_capped():
    # Generate briefs exceeding 120 lines total
    prev_brief = "\n".join(f"U: msg {i}" for i in range(80))
    fresh_brief = "\n".join(f"A: msg {i}" for i in range(80))
    prev = format_compaction([], {}, [], [], prev_brief)
    fresh = format_compaction([], {}, [], [], fresh_brief)
    merged = merge_compactions(prev, fresh)
    # Extract brief part (after separator)
    brief_part = merged.split(SEPARATOR)[-1]
    assert len(brief_part.split("\n")) <= 122  # 120 + possible omission header + blank


def test_merge_compactions_no_duplicate_files():
    fo = {"modified_files": ["x.py"], "created_files": [], "read_files": []}
    prev = format_compaction([], fo, [], [], "")
    fresh = format_compaction([], fo, [], [], "")
    merged = merge_compactions(prev, fresh)
    assert merged.count("- x.py (modified)") == 1
