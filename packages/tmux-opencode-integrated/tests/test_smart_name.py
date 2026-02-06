from pathlib import Path
import sys

import pytest

SCRIPTS_DIR = Path(__file__).resolve().parents[1] / "scripts"
sys.path.insert(0, str(SCRIPTS_DIR))

import smart_name


@pytest.mark.parametrize("cmdline,expected", [
    ("node /opt/opencode/bin/oc", "opencode"),
    ("/usr/local/bin/opencode --foo", "opencode"),
    ("oc -m claude", "opencode"),
    ("claude --model sonnet", "claude"),
    ("python script.py", "python"),
    ("nvim file.txt", "nvim"),
    ("pi --help", "pi"),
    ("-zsh", "zsh"),
])
def test_normalize_program(cmdline, expected):
    assert smart_name.normalize_program(cmdline) == expected


@pytest.mark.parametrize("program,path,expected", [
    ("zsh", "~/repo", "~/repo"),
    ("nvim", "~/repo", "nvim: ~/repo"),
    ("python", "~/repo", "python"),
    ("opencode", "~/project", "opencode: ~/project"),
    ("claude", "", "claude"),
    ("pi", "~/project", "pi: ~/project"),
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


def test_get_child_cmdline_skips_login_shells(monkeypatch):
    output = "999 -zsh\n999 pi\n"
    monkeypatch.setattr(smart_name, "run_ps", lambda args: output)
    assert smart_name.get_child_cmdline("999") == "pi"


def test_get_pane_program_with_wrapper(monkeypatch):
    """node wrapper -> detect child 'pi'."""
    pane = {"pane_current_command": "node", "pane_pid": "1234"}
    monkeypatch.setattr(smart_name, "get_child_cmdline", lambda pid: "pi")
    assert smart_name.get_pane_program(pane) == "pi"


def test_get_pane_program_shell_with_child(monkeypatch):
    """zsh -> detect child 'opencode'."""
    pane = {"pane_current_command": "zsh", "pane_pid": "1234"}
    monkeypatch.setattr(
        smart_name, "get_child_cmdline",
        lambda pid: "node /Users/tester/bin/opencode.js",
    )
    assert smart_name.get_pane_program(pane) == "opencode"


def test_get_pane_program_direct_agent():
    """pane_current_command is already an agent."""
    pane = {"pane_current_command": "amp", "pane_pid": "1234"}
    assert smart_name.get_pane_program(pane) == "amp"


def test_get_pane_program_shell_no_child(monkeypatch):
    """zsh with no interesting children -> zsh."""
    pane = {"pane_current_command": "zsh", "pane_pid": "1234"}
    monkeypatch.setattr(smart_name, "get_child_cmdline", lambda pid: "")
    assert smart_name.get_pane_program(pane) == "zsh"


def test_find_agent_panes_detects_opencode(monkeypatch):
    monkeypatch.setattr(
        smart_name, "get_child_cmdline",
        lambda pid: "opencode" if pid == "1" else "nvim",
    )

    pane1 = {"pane_current_command": "zsh", "pane_pid": "1", "pane_id": "%1"}
    pane2 = {"pane_current_command": "zsh", "pane_pid": "2", "pane_id": "%2"}

    agents = smart_name.find_agent_panes([pane1, pane2])
    assert len(agents) == 1
    assert agents[0] == (pane1, "opencode")


def test_find_agent_panes_detects_claude(monkeypatch):
    monkeypatch.setattr(
        smart_name, "get_child_cmdline",
        lambda pid: "claude --model sonnet",
    )

    pane = {"pane_current_command": "zsh", "pane_pid": "1", "pane_id": "%1"}
    agents = smart_name.find_agent_panes([pane])
    assert len(agents) == 1
    assert agents[0][1] == "claude"


def test_find_agent_panes_empty(monkeypatch):
    monkeypatch.setattr(smart_name, "get_child_cmdline", lambda pid: "zsh")

    pane = {"pane_current_command": "zsh", "pane_pid": "1", "pane_id": "%1"}
    agents = smart_name.find_agent_panes([pane])
    assert len(agents) == 0


class TestGetOpencodeStatus:
    """Tests for status pattern matching via get_opencode_status_from_content."""

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
        expected = getattr(smart_name, expected_status)
        assert smart_name.get_opencode_status_from_content(content) == expected


def test_get_opencode_status_from_content_empty():
    assert smart_name.get_opencode_status_from_content("") == smart_name.ICON_UNKNOWN


def test_strip_ansi_and_control_removes_escape_sequences():
    raw = "\x1b[32mgreen text\x1b[0m normal"
    assert smart_name.strip_ansi_and_control(raw) == "green text normal"


def test_strip_ansi_and_control_removes_control_chars():
    raw = "line1\x00\x1f\nline2"
    assert smart_name.strip_ansi_and_control(raw) == "line1\nline2"


def test_strip_ansi_and_control_preserves_unicode():
    raw = "─────╯\n● □ ■ ▲ ◇"
    assert smart_name.strip_ansi_and_control(raw) == raw


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
    status_values = [getattr(smart_name, s) for s in statuses]
    expected_value = getattr(smart_name, expected)
    assert smart_name.prioritize_status(status_values) == expected_value


def test_generate_menu_command_empty():
    assert smart_name.generate_menu_command([]) is None


def test_generate_menu_command_single_agent():
    agents = [{
        "session": "main", "window_index": "0", "window_name": "dev",
        "pane_id": "%1", "program": "opencode",
        "status": smart_name.ICON_BUSY, "path": "~/project",
    }]
    cmd = smart_name.generate_menu_command(agents)
    assert cmd is not None
    assert "display-menu" in cmd
    assert "Agent Management" in cmd
    assert "opencode" in cmd
    assert "main:0" in cmd


def test_generate_menu_command_sorts_by_priority():
    agents = [
        {
            "session": "a", "window_index": "0", "window_name": "dev",
            "pane_id": "%1", "program": "opencode",
            "status": smart_name.ICON_IDLE, "path": "",
        },
        {
            "session": "b", "window_index": "0", "window_name": "dev",
            "pane_id": "%2", "program": "claude",
            "status": smart_name.ICON_ERROR, "path": "",
        },
    ]
    cmd = smart_name.generate_menu_command(agents)
    error_pos = cmd.find("claude")
    idle_pos = cmd.find("opencode")
    assert error_pos < idle_pos


def test_generate_menu_command_attention_count():
    agents = [
        {"session": "a", "window_index": "0", "window_name": "dev",
         "pane_id": "%1", "program": "opencode", "status": smart_name.ICON_ERROR, "path": ""},
        {"session": "b", "window_index": "0", "window_name": "dev",
         "pane_id": "%2", "program": "claude", "status": smart_name.ICON_WAITING, "path": ""},
        {"session": "c", "window_index": "0", "window_name": "dev",
         "pane_id": "%3", "program": "opencode", "status": smart_name.ICON_IDLE, "path": ""},
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
    icon_value = getattr(smart_name, icon)
    expected = getattr(smart_name, expected_color)
    assert smart_name.colorize_status_icon(icon_value) == expected


@pytest.mark.parametrize("unknown_input", ["?", "X", "custom"])
def test_colorize_status_icon_passthrough(unknown_input):
    assert smart_name.colorize_status_icon(unknown_input) == unknown_input
