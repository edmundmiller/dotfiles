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


@pytest.mark.parametrize("cmdline,expected", [
    ("node /opt/opencode/bin/oc", "opencode"),
    ("/usr/local/bin/opencode --foo", "opencode"),
    ("oc -m claude", "opencode"),
    ("claude --model sonnet", "claude"),
    ("python script.py", "python"),
    ("nvim file.txt", "nvim"),
])
def test_normalize_program(cmdline, expected):
    assert smart_name.normalize_program(cmdline) == expected


@pytest.mark.parametrize("program,path,expected", [
    ("zsh", "~/repo", "~/repo"),
    ("nvim", "~/repo", "nvim: ~/repo"),
    ("python", "~/repo", "python"),
    ("opencode", "~/project", "opencode: ~/project"),
    ("claude", "", "claude"),
])
def test_build_base_name(program, path, expected):
    assert smart_name.build_base_name(program, path) == expected


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


class TestGetOpencodeStatus:
    """Tests for get_opencode_status pattern matching."""

    @pytest.mark.parametrize("content,expected_status", [
        # Error patterns
        ("Some output\nTraceback (most recent call last):\n", "ICON_ERROR"),
        ("Error: API rate limit exceeded", "ICON_ERROR"),
        ("FATAL ERROR: out of memory", "ICON_ERROR"),
        ("panic: runtime error", "ICON_ERROR"),
        # Waiting patterns
        ("Allow once?", "ICON_WAITING"),
        ("Do you want to run this command?", "ICON_WAITING"),
        ("Permission required\nyes › no › skip", "ICON_WAITING"),
        ("Press enter to continue", "ICON_WAITING"),
        # Busy patterns
        ("Thinking...", "ICON_BUSY"),
        ("Working on task ⠋", "ICON_BUSY"),
        ("≋ Running tools...  Esc to cancel", "ICON_BUSY"),
        ("■■■■■■⬝⬝  esc interrupt\nctrl+p commands", "ICON_BUSY"),
        ("Some output\nEsc to cancel", "ICON_BUSY"),
        ("Working...\n■■■■⬝⬝⬝⬝", "ICON_BUSY"),
        ("Calling tool: Read", "ICON_BUSY"),
        # Idle patterns
        ("Some output\n> ", "ICON_IDLE"),
        ("Completed task\nSession went idle", "ICON_IDLE"),
        ("Some output\n45% of 168k", "ICON_IDLE"),
        ("Created the file\nDone.", "ICON_IDLE"),
        ("ctrl+t variants  tab agents  ctrl+p commands    • OpenCode 1.1.30", "ICON_IDLE"),
        ("Some output\nctrl+p commands", "ICON_IDLE"),
        # Unknown (no patterns match)
        ("Some random output without clear status indicators", "ICON_UNKNOWN"),
    ])
    def test_status_detection(self, content, expected_status):
        """Test that pane content is correctly classified."""
        pane = DummyPaneWithCmd({}, content)
        expected = getattr(smart_name, expected_status)
        assert smart_name.get_opencode_status(pane) == expected


def test_strip_ansi_and_control_removes_escape_sequences():
    """strip_ansi_and_control removes ANSI escape sequences."""
    raw = "\x1b[32mgreen text\x1b[0m normal"
    assert smart_name.strip_ansi_and_control(raw) == "green text normal"


def test_strip_ansi_and_control_removes_control_chars():
    """strip_ansi_and_control removes control characters but keeps newlines."""
    raw = "line1\x00\x1f\nline2"
    assert smart_name.strip_ansi_and_control(raw) == "line1\nline2"


def test_strip_ansi_and_control_preserves_unicode():
    """strip_ansi_and_control preserves Unicode box-drawing chars."""
    raw = "─────╯\n● □ ■ ▲ ◇"
    assert smart_name.strip_ansi_and_control(raw) == raw


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


@pytest.mark.parametrize("statuses,expected", [
    ([], "ICON_IDLE"),
    (["ICON_IDLE"], "ICON_IDLE"),
    (["ICON_BUSY", "ICON_IDLE"], "ICON_BUSY"),
    (["ICON_WAITING", "ICON_BUSY"], "ICON_WAITING"),
    (["ICON_UNKNOWN", "ICON_WAITING"], "ICON_UNKNOWN"),
    (["ICON_ERROR", "ICON_UNKNOWN"], "ICON_ERROR"),
    (["ICON_IDLE", "ICON_BUSY", "ICON_WAITING", "ICON_ERROR"], "ICON_ERROR"),
])
def test_prioritize_status_ordering(statuses, expected):
    """Test priority ordering: ERROR > UNKNOWN > WAITING > BUSY > IDLE."""
    status_values = [getattr(smart_name, s) for s in statuses]
    expected_value = getattr(smart_name, expected)
    assert smart_name.prioritize_status(status_values) == expected_value


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


@pytest.mark.parametrize("icon,expected_color", [
    ("ICON_IDLE", "ICON_IDLE_COLOR"),
    ("ICON_BUSY", "ICON_BUSY_COLOR"),
    ("ICON_WAITING", "ICON_WAITING_COLOR"),
    ("ICON_ERROR", "ICON_ERROR_COLOR"),
    ("ICON_UNKNOWN", "ICON_UNKNOWN_COLOR"),
])
def test_colorize_status_icon(icon, expected_color):
    """colorize_status_icon returns tmux-formatted colored icons."""
    icon_value = getattr(smart_name, icon)
    expected = getattr(smart_name, expected_color)
    assert smart_name.colorize_status_icon(icon_value) == expected


@pytest.mark.parametrize("unknown_input", ["?", "X", "custom"])
def test_colorize_status_icon_passthrough(unknown_input):
    """colorize_status_icon returns input unchanged if not in mapping."""
    assert smart_name.colorize_status_icon(unknown_input) == unknown_input
