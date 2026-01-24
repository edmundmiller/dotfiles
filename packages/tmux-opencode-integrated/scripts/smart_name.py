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
ICON_UNKNOWN = "◇"  # Could not determine status (e.g., pane capture failed)


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
    """Detect OpenCode/Claude status by capturing pane content.
    
    Uses agent-specific patterns to avoid false positives from user output.
    """
    try:
        cmd_output = pane.cmd("capture-pane", "-p", "-S", "-20").stdout
        if isinstance(cmd_output, list):
            content = "\n".join(cmd_output)
        else:
            content = str(cmd_output)
    except Exception:
        return ICON_UNKNOWN

    if not content or not content.strip():
        return ICON_UNKNOWN

    # Error patterns - agent-specific crash signatures
    error_patterns = [
        r"Traceback \(most recent call last\)",  # Python errors
        r"UnhandledPromiseRejection",  # Node.js errors
        r"FATAL ERROR",
        r"panic:",  # Go panics
        r"Error: .*(API|rate limit|connection|timeout)",  # API errors
        r"(?:opencode|claude).*(?:crashed|failed|error)",
    ]
    if any(re.search(p, content, re.IGNORECASE) for p in error_patterns):
        return ICON_ERROR

    # Waiting patterns - agent permission/approval prompts
    # More specific to avoid matching arbitrary [Y/n] prompts
    waiting_patterns = [
        r"Allow (?:once|always)\?",  # Claude permission prompt
        r"Do you want to (?:run|execute|allow)",  # Generic agent prompts
        r"(?:Approve|Confirm|Accept)\?.*\[Y/n\]",
        r"Press enter to continue",  # Agent paused
        r"Waiting for (?:input|approval|confirmation)",
        r">\s*$",  # Agent prompt at end (opencode/claude input mode)
    ]
    if any(re.search(p, content, re.IGNORECASE) for p in waiting_patterns):
        return ICON_WAITING

    # Busy patterns - agent actively working
    busy_patterns = [
        r"Thinking\.{2,}",  # "Thinking..." with 2+ dots
        r"(?:Running|Executing|Processing)\.{2,}",
        r"⠋|⠙|⠹|⠸|⠼|⠴|⠦|⠧|⠇|⠏",  # Spinner characters
        r"Working on",
        r"Analyzing",
        r"Reading (?:file|files)",
        r"Writing (?:to|file)",
        r"Searching",
    ]
    if any(re.search(p, content, re.IGNORECASE) for p in busy_patterns):
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


def prioritize_status(statuses):
    """Return highest-priority status from a list.
    
    Priority: ERROR > UNKNOWN > WAITING > BUSY > IDLE
    """
    if not statuses:
        return ICON_IDLE
    if ICON_ERROR in statuses:
        return ICON_ERROR
    if ICON_UNKNOWN in statuses:
        return ICON_UNKNOWN
    if ICON_WAITING in statuses:
        return ICON_WAITING
    if ICON_BUSY in statuses:
        return ICON_BUSY
    return ICON_IDLE


def get_aggregate_agent_status(window):
    """Get highest-priority status across all agent panes in window.
    
    Priority: ERROR > UNKNOWN > WAITING > BUSY > IDLE
    Returns (status_icon, agent_count) or (None, 0) if no agents.
    """
    agent_panes = find_agent_panes(window)
    if not agent_panes:
        return None, 0
    
    statuses = [get_opencode_status(pane) for pane, _ in agent_panes]
    return prioritize_status(statuses), len(agent_panes)


def get_global_agent_status(server):
    """Get highest-priority status across ALL sessions/windows.
    
    For use in tmux status bar via #{opencode_status}.
    Returns (status_icon, agent_count, agents_needing_attention).
    """
    all_statuses = []
    agents_needing_attention = []
    
    for session in server.sessions:
        for window in session.windows:
            agent_panes = find_agent_panes(window)
            for pane, program in agent_panes:
                status = get_opencode_status(pane)
                all_statuses.append(status)
                
                if status in (ICON_ERROR, ICON_WAITING, ICON_UNKNOWN):
                    try:
                        session_name = session.name
                        window_index = window.index
                    except Exception:
                        session_name = "?"
                        window_index = "?"
                    agents_needing_attention.append({
                        "session": session_name,
                        "window": window_index,
                        "status": status,
                        "program": program,
                    })
    
    if not all_statuses:
        return None, 0, []
    
    return prioritize_status(all_statuses), len(all_statuses), agents_needing_attention


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


def print_global_status():
    """Print global agent status for tmux status bar."""
    if libtmux is None:
        return
    
    try:
        server = libtmux.Server()
        if not server.children:
            return
        
        status, count, attention = get_global_agent_status(server)
        if status:
            print(f"{status} {count}")
        # Silent if no agents
    except Exception:
        pass


if __name__ == "__main__":
    import sys
    
    if len(sys.argv) > 1 and sys.argv[1] == "--status":
        print_global_status()
    else:
        main()
