"""Tests for hermes_vcc.filter_noise."""

from hermes_vcc.filter_noise import filter_noise, clean_user_text


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def user(text):
    return {"kind": "user", "text": text}

def assistant(text):
    return {"kind": "assistant", "text": text}

def tool_call(name, args=None):
    return {"kind": "tool_call", "name": name, "args": args or {}}

def tool_result(name, text="ok", is_error=False):
    return {"kind": "tool_result", "name": name, "text": text, "is_error": is_error}

def thinking(text, redacted=False):
    return {"kind": "thinking", "text": text, "redacted": redacted}


# ---------------------------------------------------------------------------
# Tests
# ---------------------------------------------------------------------------

def test_thinking_dropped():
    blocks = [thinking("internal monologue"), assistant("hello")]
    result = filter_noise(blocks)
    assert result == [assistant("hello")]


def test_noise_tool_call_dropped():
    blocks = [tool_call("TodoWrite", {"text": "buy milk"}), assistant("done")]
    result = filter_noise(blocks)
    assert result == [assistant("done")]


def test_noise_tool_result_dropped():
    blocks = [tool_result("TodoRead", "[]"), assistant("nothing")]
    result = filter_noise(blocks)
    assert result == [assistant("nothing")]


def test_hermes_noise_tools_dropped():
    blocks = [
        tool_call("memory", {"action": "store"}),
        tool_result("memory", "stored"),
        tool_call("send_message", {"text": "ping"}),
        assistant("hi"),
    ]
    result = filter_noise(blocks)
    assert result == [assistant("hi")]


def test_noise_string_user_dropped():
    blocks = [
        user("Continue from where you left off."),
        assistant("sure"),
    ]
    result = filter_noise(blocks)
    assert result == [assistant("sure")]


def test_xml_wrapper_only_user_dropped():
    xml = "<system-reminder>do the thing</system-reminder>"
    blocks = [user(xml), assistant("ok")]
    result = filter_noise(blocks)
    assert result == [assistant("ok")]


def test_xml_wrapper_stripped_from_user_text():
    xml = "<context-window-usage>100/200k</context-window-usage>"
    blocks = [user(f"{xml}\nPlease help me debug this.")]
    result = filter_noise(blocks)
    assert len(result) == 1
    assert result[0]["kind"] == "user"
    assert "context-window-usage" not in result[0]["text"]
    assert "debug" in result[0]["text"]


def test_context_compression_tag_stripped():
    xml = "<context-compression>summary here</context-compression>"
    cleaned = clean_user_text(f"{xml}\nReal question.")
    assert "context-compression" not in cleaned
    assert "Real question." in cleaned


def test_normal_blocks_pass_through():
    blocks = [
        user("What is the capital of France?"),
        assistant("Paris."),
        tool_call("bash", {"cmd": "ls"}),
        tool_result("bash", "file.txt"),
    ]
    result = filter_noise(blocks)
    assert result == blocks


def test_empty_input():
    assert filter_noise([]) == []
