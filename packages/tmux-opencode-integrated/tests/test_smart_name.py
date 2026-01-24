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


def test_get_opencode_status_detects_error_api():
    pane = DummyPaneWithCmd({}, "Error: API rate limit exceeded")
    assert smart_name.get_opencode_status(pane) == smart_name.ICON_ERROR


def test_get_opencode_status_detects_waiting():
    pane = DummyPaneWithCmd({}, "Allow once?")
    assert smart_name.get_opencode_status(pane) == smart_name.ICON_WAITING


def test_get_opencode_status_detects_waiting_prompt():
    pane = DummyPaneWithCmd({}, "Do you want to run this command?")
    assert smart_name.get_opencode_status(pane) == smart_name.ICON_WAITING


def test_get_opencode_status_detects_busy():
    pane = DummyPaneWithCmd({}, "Thinking...")
    assert smart_name.get_opencode_status(pane) == smart_name.ICON_BUSY


def test_get_opencode_status_detects_busy_spinner():
    pane = DummyPaneWithCmd({}, "Working on task ⠋")
    assert smart_name.get_opencode_status(pane) == smart_name.ICON_BUSY


def test_get_opencode_status_defaults_to_idle():
    pane = DummyPaneWithCmd({}, "Ready for input")
    assert smart_name.get_opencode_status(pane) == smart_name.ICON_IDLE


def test_get_opencode_status_empty_content():
    pane = DummyPaneWithCmd({}, "")
    assert smart_name.get_opencode_status(pane) == smart_name.ICON_UNKNOWN


def test_get_opencode_status_capture_failure():
    class FailingPane:
        def cmd(self, *args, **kwargs):
            raise RuntimeError("capture failed")
    
    assert smart_name.get_opencode_status(FailingPane()) == smart_name.ICON_UNKNOWN


def test_get_aggregate_agent_status_priority_error(monkeypatch):
    """Error status has highest priority."""
    pane1 = DummyPaneWithCmd(
        {"pane_current_command": "opencode", "pane_pid": "1"}, "Thinking..."
    )
    pane2 = DummyPaneWithCmd(
        {"pane_current_command": "opencode", "pane_pid": "2"},
        "Traceback (most recent call last):\n  File...",
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
        {"pane_current_command": "opencode", "pane_pid": "2"}, "Allow once?"
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


def test_prioritize_status_ordering():
    """Test priority ordering: ERROR > UNKNOWN > WAITING > BUSY > IDLE."""
    assert smart_name.prioritize_status([]) == smart_name.ICON_IDLE
    assert smart_name.prioritize_status([smart_name.ICON_IDLE]) == smart_name.ICON_IDLE
    assert smart_name.prioritize_status([smart_name.ICON_BUSY, smart_name.ICON_IDLE]) == smart_name.ICON_BUSY
    assert smart_name.prioritize_status([smart_name.ICON_WAITING, smart_name.ICON_BUSY]) == smart_name.ICON_WAITING
    assert smart_name.prioritize_status([smart_name.ICON_UNKNOWN, smart_name.ICON_WAITING]) == smart_name.ICON_UNKNOWN
    assert smart_name.prioritize_status([smart_name.ICON_ERROR, smart_name.ICON_UNKNOWN]) == smart_name.ICON_ERROR


def test_get_aggregate_agent_status_unknown_priority(monkeypatch):
    """Unknown status is higher priority than waiting."""
    pane1 = DummyPaneWithCmd(
        {"pane_current_command": "opencode", "pane_pid": "1"}, ""  # Empty = unknown
    )
    pane2 = DummyPaneWithCmd(
        {"pane_current_command": "opencode", "pane_pid": "2"}, "Allow once?"
    )
    monkeypatch.setattr(smart_name, "get_child_cmdline", lambda pid: "")
    monkeypatch.setattr(smart_name, "get_cmdline_for_pid", lambda pid: "opencode")

    window = DummyWindow(pane1, panes=[pane1, pane2])
    status, count = smart_name.get_aggregate_agent_status(window)
    assert status == smart_name.ICON_UNKNOWN
    assert count == 2


class DummySession:
    def __init__(self, name, windows):
        self.name = name
        self.windows = windows


class DummyServer:
    def __init__(self, sessions):
        self.sessions = sessions
        self.children = sessions  # For compatibility check


def test_get_all_agents_info_basic(monkeypatch):
    """Test get_all_agents_info returns correct structure."""
    pane = DummyPaneWithCmd(
        {
            "pane_current_command": "opencode",
            "pane_pid": "1",
            "pane_current_path": "/home/user/project",
            "pane_id": "%1",
        },
        "Thinking...",
    )
    monkeypatch.setattr(smart_name, "get_child_cmdline", lambda pid: "")
    monkeypatch.setattr(smart_name, "get_cmdline_for_pid", lambda pid: "opencode")
    monkeypatch.setenv("HOME", "/home/user")

    window = DummyWindow(pane, panes=[pane])
    window.index = 0
    window.name = "dev"
    session = DummySession("main", [window])
    server = DummyServer([session])

    agents = smart_name.get_all_agents_info(server)
    assert len(agents) == 1
    assert agents[0]["session"] == "main"
    assert agents[0]["window_index"] == 0
    assert agents[0]["program"] == "opencode"
    assert agents[0]["status"] == smart_name.ICON_BUSY
    assert agents[0]["path"] == "~/project"
    assert agents[0]["pane_id"] == "%1"


def test_get_all_agents_info_multiple_agents(monkeypatch):
    """Test with multiple agents across sessions."""
    pane1 = DummyPaneWithCmd(
        {"pane_current_command": "opencode", "pane_pid": "1", "pane_id": "%1"},
        "Thinking...",
    )
    pane2 = DummyPaneWithCmd(
        {"pane_current_command": "claude", "pane_pid": "2", "pane_id": "%2"},
        "Allow once?",
    )
    monkeypatch.setattr(smart_name, "get_child_cmdline", lambda pid: "")
    monkeypatch.setattr(
        smart_name,
        "get_cmdline_for_pid",
        lambda pid: "opencode" if pid == "1" else "claude",
    )

    window1 = DummyWindow(pane1, panes=[pane1])
    window1.index = 0
    window1.name = "dev"
    window2 = DummyWindow(pane2, panes=[pane2])
    window2.index = 1
    window2.name = "test"

    session1 = DummySession("work", [window1])
    session2 = DummySession("personal", [window2])
    server = DummyServer([session1, session2])

    agents = smart_name.get_all_agents_info(server)
    assert len(agents) == 2
    assert agents[0]["program"] == "opencode"
    assert agents[1]["program"] == "claude"


def test_generate_menu_command_empty():
    """Empty agents list returns None."""
    assert smart_name.generate_menu_command([]) is None


def test_generate_menu_command_single_agent():
    """Generate menu with single agent."""
    agents = [
        {
            "session": "main",
            "window_index": 0,
            "window_name": "dev",
            "pane_id": "%1",
            "program": "opencode",
            "status": smart_name.ICON_BUSY,
            "path": "~/project",
        }
    ]
    cmd = smart_name.generate_menu_command(agents)
    assert cmd is not None
    assert "display-menu" in cmd
    assert "Agent Management" in cmd
    assert "opencode" in cmd
    assert "main:0" in cmd


def test_generate_menu_command_sorts_by_priority():
    """Agents needing attention should appear first."""
    agents = [
        {
            "session": "a",
            "window_index": 0,
            "window_name": "dev",
            "pane_id": "%1",
            "program": "opencode",
            "status": smart_name.ICON_IDLE,  # Low priority
            "path": "",
        },
        {
            "session": "b",
            "window_index": 0,
            "window_name": "dev",
            "pane_id": "%2",
            "program": "claude",
            "status": smart_name.ICON_ERROR,  # High priority
            "path": "",
        },
    ]
    cmd = smart_name.generate_menu_command(agents)
    # Error agent should appear before idle agent in the command
    error_pos = cmd.find("claude")
    idle_pos = cmd.find("opencode")
    assert error_pos < idle_pos


def test_generate_menu_command_attention_count():
    """Header shows correct attention count."""
    agents = [
        {
            "session": "a",
            "window_index": 0,
            "window_name": "dev",
            "pane_id": "%1",
            "program": "opencode",
            "status": smart_name.ICON_ERROR,
            "path": "",
        },
        {
            "session": "b",
            "window_index": 0,
            "window_name": "dev",
            "pane_id": "%2",
            "program": "claude",
            "status": smart_name.ICON_WAITING,
            "path": "",
        },
        {
            "session": "c",
            "window_index": 0,
            "window_name": "dev",
            "pane_id": "%3",
            "program": "opencode",
            "status": smart_name.ICON_IDLE,
            "path": "",
        },
    ]
    cmd = smart_name.generate_menu_command(agents)
    assert "3 agents" in cmd
    assert "2 need attention" in cmd
