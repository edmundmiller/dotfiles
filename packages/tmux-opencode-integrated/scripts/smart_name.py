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

ICON_IDLE = "□"
ICON_BUSY = "●"
ICON_WAITING = "■"
ICON_ERROR = "▲"
ICON_COMPLETED = "✓"


def pane_value(pane, key, default=""):
    # FIXME: pane.get() is deprecated in libtmux, migrate to attribute access
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


def get_pane_program(pane):
    """Get the program running in a pane."""
    pane_cmd = pane_value(pane, "pane_current_command", "")
    pane_pid = pane_value(pane, "pane_pid", "")

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

    return normalize_program(cmdline) or pane_cmd


def find_agent_panes(window):
    """Find all panes in a window running AI agents (opencode, claude)."""
    agent_panes = []
    for pane in window.panes:
        program = get_pane_program(pane)
        if program in ("opencode", "claude"):
            agent_panes.append((pane, program))
    return agent_panes


def get_window_context(window):
    active_pane = window.active_pane
    if not active_pane:
        return None

    pane_path = pane_value(active_pane, "pane_current_path", "")
    program = get_pane_program(active_pane)
    path = format_path(pane_path)
    base_name = build_base_name(program, path)

    return active_pane, program, path, base_name


def get_aggregate_agent_status(window):
    """Get highest-priority status across all agent panes in window.
    
    Priority: ERROR > WAITING > BUSY > IDLE
    Returns (status_icon, agent_count) or (None, 0) if no agents.
    """
    agent_panes = find_agent_panes(window)
    if not agent_panes:
        return None, 0
    
    statuses = []
    for pane, program in agent_panes:
        status = get_opencode_status(pane) or ICON_IDLE
        statuses.append(status)
    
    # Priority ordering
    if ICON_ERROR in statuses:
        return ICON_ERROR, len(agent_panes)
    if ICON_WAITING in statuses:
        return ICON_WAITING, len(agent_panes)
    if ICON_BUSY in statuses:
        return ICON_BUSY, len(agent_panes)
    return ICON_IDLE, len(agent_panes)


def main():
    if libtmux is None:
        # Silently fail if libtmux is not found (e.g. during build/check)
        return

    try:
        server = libtmux.Server()
        # FIXME: server.children is deprecated, use server.sessions instead
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

                    # Check ALL panes for agents, not just active pane
                    agent_status, agent_count = get_aggregate_agent_status(window)
                    
                    if agent_status:
                        # Window has agent(s) - show status icon
                        if program in ("opencode", "claude"):
                            # Active pane is the agent - show path
                            display_path = path or base_name or program
                            new_name = f"{agent_status} {display_path}"
                        else:
                            # Agent in background pane - show base name + indicator
                            new_name = f"{agent_status} {base_name}"
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
