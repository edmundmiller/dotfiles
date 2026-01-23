#!/usr/bin/env python3

import os
import re
import subprocess

try:
    import libtmux
except ImportError:
    # This allows the script to be edited/checked in environments without libtmux
    libtmux = None


SHELLS = ["bash", "zsh", "sh", "fish"]
DIR_PROGRAMS = ["nvim", "vim", "vi", "git", "jjui", "opencode", "claude"]
MAX_NAME_LEN = 24
USE_TILDE = True

ICON_IDLE = "○"
ICON_BUSY = "●"
ICON_WAITING = "◉"
ICON_ERROR = "✗"


def pane_value(pane, key, default=""):
    try:
        value = pane.get(key, default)
    except Exception:
        value = getattr(pane, key, default)
    return value if value is not None else default


def format_path(path):
    if not path:
        return ""
    home = os.environ.get("HOME", "")
    if USE_TILDE and home and path.startswith(home):
        return path.replace(home, "~", 1)
    return path


def run_ps(args):
    try:
        return subprocess.check_output(args, text=True).strip()
    except Exception:
        return ""


def get_cmdline_for_pid(pid):
    if not pid:
        return ""
    return run_ps(["ps", "-p", str(pid), "-o", "command="])


def get_child_cmdline(pane_pid):
    if not pane_pid:
        return ""
    output = run_ps(["ps", "-a", "-oppid=,command="])
    if not output:
        return ""
    for line in output.splitlines():
        line = line.strip()
        if not line:
            continue
        parts = line.split(None, 1)
        if len(parts) != 2:
            continue
        ppid, cmdline = parts
        if ppid == str(pane_pid):
            if "smart_name.py" in cmdline:
                continue
            return cmdline
    return ""


def normalize_program(cmdline):
    if not cmdline:
        return ""
    if re.search(r"(^|[ /])(opencode|oc)(\b|$)", cmdline):
        return "opencode"
    if re.search(r"(^|[ /])claude(\b|$)", cmdline):
        return "claude"
    base = cmdline.strip().split()[0]
    return os.path.basename(base)


def trim_name(name):
    if MAX_NAME_LEN <= 0 or len(name) <= MAX_NAME_LEN:
        return name
    if MAX_NAME_LEN <= 3:
        return name[:MAX_NAME_LEN]
    return f"{name[: MAX_NAME_LEN - 3]}..."


def build_base_name(program, path):
    if not program:
        return path or ""
    if program in SHELLS:
        return path or program
    if program in DIR_PROGRAMS:
        return f"{program}: {path}" if path else program
    return program


def get_opencode_status(pane):
    """Detect OpenCode status by capturing pane content"""
    try:
        cmd_output = pane.cmd("capture-pane", "-p", "-S", "-10").stdout
        if isinstance(cmd_output, list):
            content = "\n".join(cmd_output)
        else:
            content = str(cmd_output)
    except Exception:
        return None

    if re.search(
        r"(Traceback|UnhandledPromiseRejection|FATAL ERROR)", content, re.IGNORECASE
    ):
        return ICON_ERROR

    if re.search(r"(\[Y/n\]|Allow once|Allow always|Reject)", content):
        return ICON_WAITING

    if re.search(r"(Thinking\.\.\.|Running\.\.\.|Executing)", content, re.IGNORECASE):
        return ICON_BUSY

    return ICON_IDLE


def get_window_context(window):
    active_pane = window.active_pane
    if not active_pane:
        return None

    pane_path = pane_value(active_pane, "pane_current_path", "")
    pane_cmd = pane_value(active_pane, "pane_current_command", "")
    pane_pid = pane_value(active_pane, "pane_pid", "")

    cmdline = ""
    if pane_pid:
        if pane_cmd in SHELLS:
            cmdline = get_child_cmdline(pane_pid)
            if not cmdline:
                cmdline = get_cmdline_for_pid(pane_pid)
        else:
            cmdline = get_cmdline_for_pid(pane_pid)

    if not cmdline:
        cmdline = pane_cmd

    program = normalize_program(cmdline) or pane_cmd
    path = format_path(pane_path)
    base_name = build_base_name(program, path)

    return active_pane, program, path, base_name


def main():
    if libtmux is None:
        # Silently fail if libtmux is not found (e.g. during build/check)
        return

    try:
        server = libtmux.Server()
        if not server.children:
            return

        for session in server.sessions:
            for window in session.windows:
                try:
                    context = get_window_context(window)
                    if not context:
                        continue
                    active_pane, program, path, base_name = context

                    if not base_name and not program:
                        continue

                    if program == "opencode":
                        status_icon = get_opencode_status(active_pane) or ICON_IDLE
                        display_path = path or base_name or "opencode"
                        new_name = f"{status_icon} OC | {display_path}"
                    else:
                        new_name = base_name

                    new_name = trim_name(new_name)

                    try:
                        current_name = window.name
                    except Exception:
                        current_name = ""

                    if current_name != new_name:
                        window.rename_window(new_name)
                except Exception:
                    continue
    except Exception:
        pass


if __name__ == "__main__":
    main()
