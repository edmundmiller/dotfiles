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
    def __init__(self, pane):
        self.active_pane = pane


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
