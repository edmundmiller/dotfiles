from pathlib import Path
import sys

import pytest

SCRIPTS_DIR = Path(__file__).resolve().parents[1] / "scripts"
sys.path.insert(0, str(SCRIPTS_DIR))

import smart_name


class DummyPane:
    def __init__(self, values):
        self._values = values

    def get(self, key, default=None):
        return self._values.get(key, default)


class DummyWindow:
    def __init__(self, pane, panes=None):
        self.active_pane = pane
        self.panes = panes if panes is not None else [pane]


def test_normalize_program_detects_opencode():
    assert smart_name.normalize_program("node /opt/opencode/bin/oc") == "opencode"
    assert smart_name.normalize_program("/usr/local/bin/opencode --foo") == "opencode"
    assert smart_name.normalize_program("oc -m claude") == "opencode"


def test_normalize_program_detects_claude():
    assert smart_name.normalize_program("claude --model sonnet") == "claude"


def test_build_base_name():
    assert smart_name.build_base_name("zsh", "~/repo") == "~/repo"
    assert smart_name.build_base_name("nvim", "~/repo") == "nvim: ~/repo"
    assert smart_name.build_base_name("python", "~/repo") == "python"


def test_trim_name(monkeypatch):
    monkeypatch.setattr(smart_name, "MAX_NAME_LEN", 6)
    assert smart_name.trim_name("abcdefg") == "abc..."
    monkeypatch.setattr(smart_name, "MAX_NAME_LEN", 3)
    assert smart_name.trim_name("abcdefg") == "abc"


def test_get_child_cmdline_skips_smart_name(monkeypatch):
    output = "999 smart_name.py --run\n999 nvim\n"
    monkeypatch.setattr(smart_name, "run_ps", lambda args: output)
    assert smart_name.get_child_cmdline("999") == "nvim"


def test_get_window_context_uses_child_cmdline(monkeypatch):
    pane = DummyPane(
        {
            "pane_current_path": "/Users/tester/project",
            "pane_current_command": "zsh",
            "pane_pid": "1234",
        }
    )
    window = DummyWindow(pane)
    monkeypatch.setenv("HOME", "/Users/tester")
    monkeypatch.setattr(
        smart_name,
        "get_child_cmdline",
        lambda pid: "node /Users/tester/bin/opencode.js",
    )
    monkeypatch.setattr(smart_name, "get_cmdline_for_pid", lambda pid: "")

    active_pane, program, path, base_name = smart_name.get_window_context(window)
    assert active_pane is pane
    assert program == "opencode"
    assert path == "~/project"
    assert base_name == "opencode: ~/project"


class DummyPaneWithCmd:
    """Pane that also supports cmd() for capture-pane."""

    def __init__(self, values, content=""):
        self._values = values
        self._content = content

    def get(self, key, default=None):
        return self._values.get(key, default)

    def cmd(self, *args, **kwargs):
        class Result:
            def __init__(self, content):
                self.stdout = content.split("\n")

        return Result(self._content)


def test_find_agent_panes_detects_opencode(monkeypatch):
    monkeypatch.setattr(smart_name, "get_child_cmdline", lambda pid: "opencode")
    monkeypatch.setattr(smart_name, "get_cmdline_for_pid", lambda pid: "")

    pane1 = DummyPane({"pane_current_command": "zsh", "pane_pid": "1"})
    pane2 = DummyPane({"pane_current_command": "zsh", "pane_pid": "2"})

    monkeypatch.setattr(
        smart_name,
        "get_child_cmdline",
        lambda pid: "opencode" if pid == "1" else "nvim",
    )

    window = DummyWindow(pane1, panes=[pane1, pane2])
    agents = smart_name.find_agent_panes(window)
    assert len(agents) == 1
    assert agents[0] == (pane1, "opencode")


def test_find_agent_panes_detects_claude(monkeypatch):
    monkeypatch.setattr(
        smart_name, "get_child_cmdline", lambda pid: "claude --model sonnet"
    )
    monkeypatch.setattr(smart_name, "get_cmdline_for_pid", lambda pid: "")

    pane = DummyPane({"pane_current_command": "zsh", "pane_pid": "1"})
    window = DummyWindow(pane, panes=[pane])
    agents = smart_name.find_agent_panes(window)
    assert len(agents) == 1
    assert agents[0][1] == "claude"


def test_find_agent_panes_empty_window(monkeypatch):
    monkeypatch.setattr(smart_name, "get_child_cmdline", lambda pid: "zsh")
    monkeypatch.setattr(smart_name, "get_cmdline_for_pid", lambda pid: "")

    pane = DummyPane({"pane_current_command": "zsh", "pane_pid": "1"})
    window = DummyWindow(pane, panes=[pane])
    agents = smart_name.find_agent_panes(window)
    assert len(agents) == 0


def test_get_opencode_status_detects_error():
    pane = DummyPaneWithCmd({}, "Some output\nTraceback (most recent call last):\n")
    assert smart_name.get_opencode_status(pane) == smart_name.ICON_ERROR


def test_get_opencode_status_detects_waiting():
    pane = DummyPaneWithCmd({}, "Allow this action? [Y/n]")
    assert smart_name.get_opencode_status(pane) == smart_name.ICON_WAITING


def test_get_opencode_status_detects_busy():
    pane = DummyPaneWithCmd({}, "Thinking...")
    assert smart_name.get_opencode_status(pane) == smart_name.ICON_BUSY


def test_get_opencode_status_defaults_to_idle():
    pane = DummyPaneWithCmd({}, "Ready for input")
    assert smart_name.get_opencode_status(pane) == smart_name.ICON_IDLE


def test_get_aggregate_agent_status_priority_error(monkeypatch):
    """Error status has highest priority."""
    pane1 = DummyPaneWithCmd(
        {"pane_current_command": "opencode", "pane_pid": "1"}, "Thinking..."
    )
    pane2 = DummyPaneWithCmd(
        {"pane_current_command": "opencode", "pane_pid": "2"}, "Traceback error"
    )
    monkeypatch.setattr(smart_name, "get_child_cmdline", lambda pid: "")
    monkeypatch.setattr(smart_name, "get_cmdline_for_pid", lambda pid: "opencode")

    window = DummyWindow(pane1, panes=[pane1, pane2])
    status, count = smart_name.get_aggregate_agent_status(window)
    assert status == smart_name.ICON_ERROR
    assert count == 2


def test_get_aggregate_agent_status_priority_waiting(monkeypatch):
    """Waiting beats busy."""
    pane1 = DummyPaneWithCmd(
        {"pane_current_command": "opencode", "pane_pid": "1"}, "Thinking..."
    )
    pane2 = DummyPaneWithCmd(
        {"pane_current_command": "opencode", "pane_pid": "2"}, "[Y/n]"
    )
    monkeypatch.setattr(smart_name, "get_child_cmdline", lambda pid: "")
    monkeypatch.setattr(smart_name, "get_cmdline_for_pid", lambda pid: "opencode")

    window = DummyWindow(pane1, panes=[pane1, pane2])
    status, count = smart_name.get_aggregate_agent_status(window)
    assert status == smart_name.ICON_WAITING
    assert count == 2


def test_get_aggregate_agent_status_no_agents(monkeypatch):
    """No agents returns None."""
    pane = DummyPane({"pane_current_command": "zsh", "pane_pid": "1"})
    monkeypatch.setattr(smart_name, "get_child_cmdline", lambda pid: "nvim")
    monkeypatch.setattr(smart_name, "get_cmdline_for_pid", lambda pid: "")

    window = DummyWindow(pane, panes=[pane])
    status, count = smart_name.get_aggregate_agent_status(window)
    assert status is None
    assert count == 0
