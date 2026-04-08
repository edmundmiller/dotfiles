"""Tests for hermes_vcc.extract"""

import pytest
from hermes_vcc.extract import (
    extract_goals,
    extract_preferences,
    extract_file_ops,
    _clip,
    _non_empty_lines,
)


# ---------------------------------------------------------------------------
# Helper tests
# ---------------------------------------------------------------------------

def test_clip_short():
    assert _clip("hello") == "hello"


def test_clip_truncates():
    long = "x" * 300
    assert len(_clip(long)) == 200


def test_non_empty_lines():
    text = "line one\n\n  \nline two\n"
    assert _non_empty_lines(text) == ["line one", "line two"]


# ---------------------------------------------------------------------------
# extract_goals
# ---------------------------------------------------------------------------

def user(text):
    return {"kind": "user", "text": text}


def assistant(text):
    return {"kind": "assistant", "text": text}


def test_goals_empty():
    assert extract_goals([]) == []


def test_goals_ignores_non_user():
    blocks = [assistant("implement something interesting here")]
    assert extract_goals(blocks) == []


def test_goals_ignores_noise():
    blocks = [user("ok"), user("yes"), user("sure")]
    assert extract_goals(blocks) == []


def test_goals_first_user_block():
    blocks = [user("Implement a login system with OAuth")]
    result = extract_goals(blocks)
    assert result == ["Implement a login system with OAuth"]


def test_goals_scope_change_appended():
    blocks = [
        user("Build a REST API for user management"),
        user("Actually, instead of REST let's use GraphQL now"),
    ]
    result = extract_goals(blocks)
    assert "[Scope change]" in result
    assert any("GraphQL" in g for g in result)


def test_goals_task_re_scope_change():
    blocks = [
        user("Build a REST API for user management"),
        user("Refactor the entire authentication module please"),
    ]
    result = extract_goals(blocks)
    assert "[Scope change]" in result


def test_goals_max_8():
    blocks = [user("Fix the login bug in the authentication service please")]
    # Force many scope changes
    for i in range(10):
        blocks.append(user(f"Actually, instead do task number {i} which is very important"))
    result = extract_goals(blocks)
    assert len(result) <= 8


def test_goals_only_last_scope_change_counts():
    blocks = [
        user("Build something cool and interesting for users"),
        user("Instead, switch to building a CLI tool for developers"),
        user("Actually, forget that and build a web scraper now"),
    ]
    result = extract_goals(blocks)
    assert any("scraper" in g for g in result)
    # The intermediate scope change should not appear
    assert not any("CLI" in g for g in result)


# ---------------------------------------------------------------------------
# extract_preferences
# ---------------------------------------------------------------------------

def test_prefs_empty():
    assert extract_preferences([]) == []


def test_prefs_prefer():
    blocks = [user("I prefer snake_case for variable names")]
    result = extract_preferences(blocks)
    assert len(result) == 1
    assert "prefer" in result[0]


def test_prefs_dont_want():
    blocks = [user("Please don't want any global variables in the code")]
    result = extract_preferences(blocks)
    assert len(result) == 1


def test_prefs_always_never():
    blocks = [user("Always add type hints\nNever use print for logging")]
    result = extract_preferences(blocks)
    assert len(result) == 2


def test_prefs_please_use():
    blocks = [user("Please use black for formatting")]
    result = extract_preferences(blocks)
    assert len(result) == 1


def test_prefs_style_format_language():
    blocks = [user("style: PEP8\nformat: compact\nlanguage: Python only")]
    result = extract_preferences(blocks)
    assert len(result) == 3


def test_prefs_deduplication():
    blocks = [
        user("I prefer tabs over spaces"),
        user("I prefer tabs over spaces"),
    ]
    result = extract_preferences(blocks)
    assert len(result) == 1


def test_prefs_max_10():
    lines = [f"Always remember rule number {i} in this codebase" for i in range(20)]
    blocks = [user("\n".join(lines))]
    result = extract_preferences(blocks)
    assert len(result) == 10


def test_prefs_ignores_non_user():
    blocks = [assistant("I prefer to always use tabs here")]
    assert extract_preferences(blocks) == []


def test_prefs_ignores_short():
    blocks = [user("ok")]
    assert extract_preferences(blocks) == []


# ---------------------------------------------------------------------------
# extract_file_ops
# ---------------------------------------------------------------------------

def tool_call(name, **args):
    return {"kind": "tool_call", "name": name, "args": args}


def test_file_ops_empty():
    result = extract_file_ops([])
    assert result == {"read_files": [], "modified_files": [], "created_files": []}


def test_file_ops_read_tools():
    blocks = [
        tool_call("read_file", path="/src/main.py"),
        tool_call("cat", path="/etc/hosts"),
        tool_call("web_extract", url="https://example.com"),
        tool_call("web_search", url="https://search.example.com"),
        tool_call("browser_navigate", url="https://docs.example.com"),
    ]
    result = extract_file_ops(blocks)
    assert len(result["read_files"]) == 5
    assert result["modified_files"] == []
    assert result["created_files"] == []


def test_file_ops_write_tools():
    blocks = [
        tool_call("write_file", path="/src/output.py"),
        tool_call("patch", path="/src/main.py"),
        tool_call("edit_file", path="/src/utils.py"),
        tool_call("str_replace_editor", path="/src/config.py"),
    ]
    result = extract_file_ops(blocks)
    assert len(result["modified_files"]) == 4
    assert result["read_files"] == []
    assert result["created_files"] == []


def test_file_ops_create_tools():
    blocks = [
        tool_call("touch", path="/src/new.py"),
        tool_call("mkdir", path="/src/new_dir"),
        tool_call("create_file", path="/src/another.py"),
    ]
    result = extract_file_ops(blocks)
    assert len(result["created_files"]) == 3


def test_file_ops_deduplication():
    blocks = [
        tool_call("read_file", path="/src/main.py"),
        tool_call("read_file", path="/src/main.py"),
    ]
    result = extract_file_ops(blocks)
    assert len(result["read_files"]) == 1


def test_file_ops_ignores_missing_path():
    blocks = [tool_call("read_file")]  # no path arg
    result = extract_file_ops(blocks)
    assert result["read_files"] == []


def test_file_ops_filename_arg():
    blocks = [tool_call("write_file", filename="/src/out.txt")]
    result = extract_file_ops(blocks)
    assert "/src/out.txt" in result["modified_files"]


def test_file_ops_ignores_non_tool_call():
    blocks = [
        {"kind": "user", "text": "read_file /src/main.py"},
        {"kind": "assistant", "text": "patch /src/main.py"},
    ]
    result = extract_file_ops(blocks)
    assert result == {"read_files": [], "modified_files": [], "created_files": []}


def test_file_ops_unknown_tool_ignored():
    blocks = [tool_call("unknown_tool", path="/src/main.py")]
    result = extract_file_ops(blocks)
    assert result == {"read_files": [], "modified_files": [], "created_files": []}
