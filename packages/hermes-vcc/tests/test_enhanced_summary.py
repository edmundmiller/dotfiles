"""Tests for compile_to_brief — the pure VCC summary."""

from hermes_vcc.enhanced_summary import compile_to_brief


class TestCompileToBrief:
    def test_returns_content(self, basic_conversation, vcc_py_path):
        result = compile_to_brief(basic_conversation)
        assert result is not None
        assert len(result) > 0

    def test_empty_messages(self):
        assert compile_to_brief([]) is None

    def test_tool_calls_collapsed(self, tool_heavy_session, vcc_py_path):
        result = compile_to_brief(tool_heavy_session)
        assert result is not None
        # VCC .min.txt collapses tool calls to one-liners with line refs
        assert "Read" in result or "Edit" in result or "Grep" in result

    def test_thinking_hidden(self, thinking_session, vcc_py_path):
        result = compile_to_brief(thinking_session)
        assert result is not None
        # .min.txt hides thinking blocks
        assert ">>>thinking" not in result
