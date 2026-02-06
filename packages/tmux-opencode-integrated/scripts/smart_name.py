#!/usr/bin/env python3
"""Smart tmux window naming with AI agent status detection.

No external dependencies — uses subprocess to talk to tmux directly.
"""

import os
import re
import subprocess


# ── Config ──────────────────────────────────────────────────────────────────

SHELLS = ["bash", "zsh", "sh", "fish"]
# Programs that wrap/run other things — treat like shells for child detection
WRAPPERS = ["node", "python3", "python", "ruby", "bun"]
DIR_PROGRAMS = ["nvim", "vim", "vi", "git", "jjui", "opencode", "claude", "amp", "pi"]
AGENT_PROGRAMS = ["opencode", "claude", "amp"]
MAX_NAME_LEN = 24
USE_TILDE = True

ICON_IDLE = "□"
ICON_BUSY = "●"
ICON_WAITING = "■"
ICON_ERROR = "▲"
ICON_UNKNOWN = "◇"

ICON_IDLE_COLOR = "#[fg=blue]□#[default]"
ICON_BUSY_COLOR = "#[fg=cyan]●#[default]"
ICON_WAITING_COLOR = "#[fg=yellow]■#[default]"
ICON_ERROR_COLOR = "#[fg=red]▲#[default]"
ICON_UNKNOWN_COLOR = "#[fg=magenta]◇#[default]"

ICON_TO_COLOR = {
    ICON_IDLE: ICON_IDLE_COLOR,
    ICON_BUSY: ICON_BUSY_COLOR,
    ICON_WAITING: ICON_WAITING_COLOR,
    ICON_ERROR: ICON_ERROR_COLOR,
    ICON_UNKNOWN: ICON_UNKNOWN_COLOR,
}


# ── Tmux helpers (replaces libtmux) ────────────────────────────────────────

def tmux_cmd(*args):
    """Run a tmux command, return stdout lines. Empty list on failure."""
    try:
        result = subprocess.run(
            ["tmux"] + list(args),
            capture_output=True, text=True, timeout=5,
        )
        if result.returncode != 0:
            return []
        return result.stdout.splitlines()
    except Exception:
        return []


def tmux_has_sessions():
    return bool(tmux_cmd("list-sessions", "-F", "#{session_id}"))


def tmux_list_sessions():
    """Return list of dicts with session info."""
    lines = tmux_cmd("list-sessions", "-F", "#{session_id}\t#{session_name}")
    sessions = []
    for line in lines:
        parts = line.split("\t", 1)
        if len(parts) == 2:
            sessions.append({"id": parts[0], "name": parts[1]})
    return sessions


def tmux_list_windows(session_id):
    """Return list of dicts with window info for a session."""
    fmt = "#{window_id}\t#{window_index}\t#{window_name}"
    lines = tmux_cmd("list-windows", "-t", session_id, "-F", fmt)
    windows = []
    for line in lines:
        parts = line.split("\t", 2)
        if len(parts) == 3:
            windows.append({"id": parts[0], "index": parts[1], "name": parts[2]})
    return windows


def tmux_list_panes(window_id):
    """Return list of dicts with pane info for a window."""
    fmt = "\t".join([
        "#{pane_id}", "#{pane_pid}", "#{pane_current_command}",
        "#{pane_current_path}", "#{pane_active}",
    ])
    lines = tmux_cmd("list-panes", "-t", window_id, "-F", fmt)
    panes = []
    for line in lines:
        parts = line.split("\t", 4)
        if len(parts) == 5:
            panes.append({
                "pane_id": parts[0],
                "pane_pid": parts[1],
                "pane_current_command": parts[2],
                "pane_current_path": parts[3],
                "active": parts[4] == "1",
            })
    return panes


def tmux_capture_pane(pane_id, lines=20):
    """Capture last N lines from a pane."""
    return "\n".join(tmux_cmd("capture-pane", "-p", "-t", pane_id, "-S", f"-{lines}"))


def tmux_rename_window(window_id, name):
    tmux_cmd("rename-window", "-t", window_id, name)


# ── Process detection ───────────────────────────────────────────────────────

def colorize_status_icon(status):
    return ICON_TO_COLOR.get(status, status)


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
            # Skip login shells (e.g. "-zsh") — we want the real child program
            cmd_base = cmdline.strip().split()[0]
            if cmd_base.startswith("-"):
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
    if re.search(r"(^|[ /])pi(\s|$)", cmdline):
        return "pi"
    base = cmdline.strip().split()[0]
    name = os.path.basename(base)
    # Strip login shell prefix (e.g. "-zsh" -> "zsh")
    if name.startswith("-"):
        name = name[1:]
    return name


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


def strip_ansi_and_control(text):
    """Remove ANSI escape sequences and control characters from text."""
    text = re.sub(r'\x1b\[[0-9;]*[a-zA-Z]', '', text)
    text = re.sub(r'\x1b\][^\x07]*\x07', '', text)  # OSC sequences
    text = re.sub(r'\x1b[PX^_][^\x1b]*\x1b\\', '', text)  # DCS/PM/APC/SOS
    text = re.sub(r'[\x00-\x08\x0b\x0c\x0e-\x1f\x7f-\x9f]', '', text)
    return text


# ── Agent status detection ──────────────────────────────────────────────────

def get_opencode_status(pane_id):
    """Detect agent status by capturing pane content.

    Accepts a pane_id string (e.g. "%5") for tmux capture-pane.
    """
    content = tmux_capture_pane(pane_id)
    if not content or not content.strip():
        return ICON_UNKNOWN

    content = strip_ansi_and_control(content)

    # Error patterns
    error_patterns = [
        r"Traceback \(most recent call last\)",
        r"UnhandledPromiseRejection",
        r"FATAL ERROR",
        r"panic:",
        r"Error: .*(API|rate limit|connection|timeout)",
        r"(?:opencode|claude).*(?:crashed|failed|error)",
    ]
    if any(re.search(p, content, re.IGNORECASE) for p in error_patterns):
        return ICON_ERROR

    # Waiting patterns
    waiting_patterns = [
        r"Allow (?:once|always)\?",
        r"Do you want to (?:run|execute|allow)",
        r"(?:Approve|Confirm|Accept)\?.*\[Y/n\]",
        r"Press enter to continue",
        r"Waiting for (?:input|approval|confirmation)",
        r"Permission required",
        r"(?:yes|no|skip)\s*›",
    ]
    if any(re.search(p, content, re.IGNORECASE) for p in waiting_patterns):
        return ICON_WAITING

    # Busy patterns
    busy_patterns = [
        r"Thinking\.{2,}",
        r"(?:Running|Executing|Processing)\.{2,}",
        r"⠋|⠙|⠹|⠸|⠼|⠴|⠦|⠧|⠇|⠏",
        r"Working on",
        r"Analyzing",
        r"Reading (?:file|files)",
        r"Writing (?:to|file)",
        r"Searching",
        r"Calling tool",
        r"Tool:",
        r"⎿",
        r"Running tools",
        r"≋",
        r"■■■",
        r"esc interrupt",
        r"Esc to cancel",
    ]
    if any(re.search(p, content, re.IGNORECASE) for p in busy_patterns):
        return ICON_BUSY

    # Idle patterns
    idle_patterns = [
        r">\s*$",
        r"❯\s*$",
        r"│\s*$",
        r"What would you like",
        r"How can I help",
        r"Session went idle",
        r"Finished\s*$",
        r"Done\.\s*$",
        r"completed successfully",
        r"\d+% of \d+k",
        r"OpenCode \d+\.\d+\.\d+",
        r"ctrl\+p commands",
    ]
    if any(re.search(p, content, re.IGNORECASE | re.MULTILINE) for p in idle_patterns):
        return ICON_IDLE

    return ICON_UNKNOWN


# Also support dict-based panes for testing (capture-pane via .cmd())
def get_opencode_status_from_content(content):
    """Detect status from raw content string. Used by tests."""
    if not content or not content.strip():
        return ICON_UNKNOWN

    content = strip_ansi_and_control(content)

    error_patterns = [
        r"Traceback \(most recent call last\)",
        r"UnhandledPromiseRejection",
        r"FATAL ERROR",
        r"panic:",
        r"Error: .*(API|rate limit|connection|timeout)",
        r"(?:opencode|claude).*(?:crashed|failed|error)",
    ]
    if any(re.search(p, content, re.IGNORECASE) for p in error_patterns):
        return ICON_ERROR

    waiting_patterns = [
        r"Allow (?:once|always)\?",
        r"Do you want to (?:run|execute|allow)",
        r"(?:Approve|Confirm|Accept)\?.*\[Y/n\]",
        r"Press enter to continue",
        r"Waiting for (?:input|approval|confirmation)",
        r"Permission required",
        r"(?:yes|no|skip)\s*›",
    ]
    if any(re.search(p, content, re.IGNORECASE) for p in waiting_patterns):
        return ICON_WAITING

    busy_patterns = [
        r"Thinking\.{2,}",
        r"(?:Running|Executing|Processing)\.{2,}",
        r"⠋|⠙|⠹|⠸|⠼|⠴|⠦|⠧|⠇|⠏",
        r"Working on",
        r"Analyzing",
        r"Reading (?:file|files)",
        r"Writing (?:to|file)",
        r"Searching",
        r"Calling tool",
        r"Tool:",
        r"⎿",
        r"Running tools",
        r"≋",
        r"■■■",
        r"esc interrupt",
        r"Esc to cancel",
    ]
    if any(re.search(p, content, re.IGNORECASE) for p in busy_patterns):
        return ICON_BUSY

    idle_patterns = [
        r">\s*$",
        r"❯\s*$",
        r"│\s*$",
        r"What would you like",
        r"How can I help",
        r"Session went idle",
        r"Finished\s*$",
        r"Done\.\s*$",
        r"completed successfully",
        r"\d+% of \d+k",
        r"OpenCode \d+\.\d+\.\d+",
        r"ctrl\+p commands",
    ]
    if any(re.search(p, content, re.IGNORECASE | re.MULTILINE) for p in idle_patterns):
        return ICON_IDLE

    return ICON_UNKNOWN


# ── Pane/window analysis ───────────────────────────────────────────────────

def get_pane_program(pane):
    """Get the program running in a pane (dict from tmux_list_panes)."""
    pane_cmd = pane.get("pane_current_command", "")
    pane_pid = pane.get("pane_pid", "")

    if pane_cmd in AGENT_PROGRAMS:
        return pane_cmd

    if pane_pid:
        if pane_cmd in SHELLS or pane_cmd in WRAPPERS:
            cmdline = get_child_cmdline(pane_pid)
            if cmdline:
                return normalize_program(cmdline) or pane_cmd

    return pane_cmd


def find_agent_panes(panes):
    """Find panes running AI agents from a list of pane dicts."""
    agents = []
    for pane in panes:
        program = get_pane_program(pane)
        if program in AGENT_PROGRAMS:
            agents.append((pane, program))
    return agents


def prioritize_status(statuses):
    """Return highest-priority status. ERROR > UNKNOWN > WAITING > BUSY > IDLE."""
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


def get_aggregate_agent_status(panes):
    """Get highest-priority status across agent panes.

    Returns (status_icon, agent_count) or (None, 0) if no agents.
    """
    agent_panes = find_agent_panes(panes)
    if not agent_panes:
        return None, 0

    statuses = [get_opencode_status(p["pane_id"]) for p, _ in agent_panes]
    return prioritize_status(statuses), len(agent_panes)


# ── Main rename logic ──────────────────────────────────────────────────────

def main():
    if not tmux_has_sessions():
        return

    try:
        for session in tmux_list_sessions():
            for window in tmux_list_windows(session["id"]):
                try:
                    panes = tmux_list_panes(window["id"])
                    if not panes:
                        continue

                    # Find active pane
                    active = next((p for p in panes if p["active"]), panes[0])

                    program = get_pane_program(active)
                    path = format_path(active.get("pane_current_path", ""))
                    base_name = build_base_name(program, path)

                    if not base_name and not program:
                        continue

                    # Check ALL panes for agents
                    agent_status, agent_count = get_aggregate_agent_status(panes)

                    if agent_status:
                        colored_icon = colorize_status_icon(agent_status)
                        if program in AGENT_PROGRAMS:
                            display_path = path or base_name or program
                            new_name = f"{colored_icon} {display_path}"
                        else:
                            new_name = f"{colored_icon} {base_name}"
                    else:
                        new_name = base_name

                    new_name = trim_name(new_name)

                    if window["name"] != new_name:
                        tmux_rename_window(window["id"], new_name)
                except Exception:
                    continue
    except Exception:
        pass


# ── Status bar / menu commands ──────────────────────────────────────────────

def get_global_agent_status():
    """Get highest-priority status across ALL sessions/windows."""
    all_statuses = []
    agents_needing_attention = []

    for session in tmux_list_sessions():
        for window in tmux_list_windows(session["id"]):
            panes = tmux_list_panes(window["id"])
            agent_panes = find_agent_panes(panes)
            for pane, program in agent_panes:
                status = get_opencode_status(pane["pane_id"])
                all_statuses.append(status)

                if status in (ICON_ERROR, ICON_WAITING, ICON_UNKNOWN):
                    agents_needing_attention.append({
                        "session": session["name"],
                        "window": window["index"],
                        "status": status,
                        "program": program,
                    })

    if not all_statuses:
        return None, 0, []

    return prioritize_status(all_statuses), len(all_statuses), agents_needing_attention


def print_global_status():
    try:
        if not tmux_has_sessions():
            return
        status, count, _ = get_global_agent_status()
        if status:
            print(f"{status} {count}")
    except Exception:
        pass


def get_all_agents_info():
    """Get detailed info for all agents across all sessions."""
    agents = []
    for session in tmux_list_sessions():
        for window in tmux_list_windows(session["id"]):
            panes = tmux_list_panes(window["id"])
            agent_panes = find_agent_panes(panes)
            for pane, program in agent_panes:
                status = get_opencode_status(pane["pane_id"])
                agents.append({
                    "session": session["name"],
                    "window_index": window["index"],
                    "window_name": window["name"],
                    "pane_id": pane["pane_id"],
                    "program": program,
                    "status": status,
                    "path": format_path(pane.get("pane_current_path", "")),
                })
    return agents


def generate_menu_command(agents):
    """Generate a tmux display-menu command string."""
    if not agents:
        return None

    priority = {ICON_ERROR: 0, ICON_UNKNOWN: 1, ICON_WAITING: 2, ICON_BUSY: 3, ICON_IDLE: 4}
    agents_sorted = sorted(agents, key=lambda a: (priority.get(a["status"], 5), a["session"], a["window_index"]))

    menu_items = []

    statuses = [a["status"] for a in agents]
    aggregate = prioritize_status(statuses)
    count = len(agents)
    attention_count = sum(1 for s in statuses if s in (ICON_ERROR, ICON_UNKNOWN, ICON_WAITING))

    if attention_count > 0:
        header = f"{aggregate} {count} agents ({attention_count} need attention)"
    else:
        header = f"{aggregate} {count} agents"

    menu_items.append(f'"{header}" "" ""')
    menu_items.append('"-" "" ""')

    for i, agent in enumerate(agents_sorted):
        status = agent["status"]
        program = agent["program"]
        session = agent["session"]
        window_idx = agent["window_index"]
        pane_id = agent["pane_id"]
        path = agent["path"]

        if path and len(path) > 20:
            path = "..." + path[-17:]

        label = f"{status} {program} {session}:{window_idx}"
        if path:
            label += f" {path}"

        key = str(i + 1) if i < 9 else ""

        if pane_id:
            action = f"switch-client -t {session}:{window_idx} ; select-pane -t {pane_id}"
        else:
            action = f"switch-client -t {session}:{window_idx}"

        menu_items.append(f'"{label}" "{key}" "{action}"')

    menu_items.append('"-" "" ""')
    menu_items.append('"Refresh" "r" "run-shell -b \\\"#{TMUX_OPENCODE_MENU_CMD}\\\""')
    menu_items.append('"Close" "q" ""')

    items_str = " ".join(menu_items)
    return f'display-menu -T "Agent Management" -x C -y C {items_str}'


def run_menu():
    """Execute the agent management menu directly."""
    try:
        if not tmux_has_sessions():
            subprocess.run(["tmux", "display-message", "No tmux sessions"])
            return

        agents = get_all_agents_info()
        if not agents:
            subprocess.run(["tmux", "display-message", "No AI agents running"])
            return

        priority = {ICON_ERROR: 0, ICON_UNKNOWN: 1, ICON_WAITING: 2, ICON_BUSY: 3, ICON_IDLE: 4}
        agents_sorted = sorted(agents, key=lambda a: (priority.get(a["status"], 5), a["session"], a["window_index"]))

        menu_args = ["-T", "Agent Management", "-x", "C", "-y", "C", "-C", "1"]

        statuses = [a["status"] for a in agents]
        aggregate = prioritize_status(statuses)
        count = len(agents)
        attention_count = sum(1 for s in statuses if s in (ICON_ERROR, ICON_UNKNOWN, ICON_WAITING))

        aggregate_color = ICON_TO_COLOR.get(aggregate, aggregate)
        if attention_count > 0:
            header = f"{aggregate_color} {count} agents ({attention_count} need attention)"
        else:
            header = f"{aggregate_color} {count} agents"

        menu_args.extend([header, "", ""])
        menu_args.extend(["", "", ""])  # Separator

        for i, agent in enumerate(agents_sorted):
            status = agent["status"]
            status_color = ICON_TO_COLOR.get(status, status)
            program = agent["program"]
            session = agent["session"]
            window_idx = agent["window_index"]
            pane_id = agent["pane_id"]
            path = agent["path"]

            if path and len(path) > 20:
                path = "..." + path[-17:]

            label = f"{status_color} {program} {session}:{window_idx}"
            if path:
                label += f" {path}"

            key = str(i + 1) if i < 9 else ""

            if pane_id:
                action = f"switch-client -t {session}:{window_idx} ; select-pane -t {pane_id}"
            else:
                action = f"switch-client -t {session}:{window_idx}"

            menu_args.extend([label, key, action])

            if pane_id and status == ICON_BUSY:
                interrupt_action = f"send-keys -t {pane_id} Escape"
                menu_args.extend(["  ⏹ Interrupt", "", interrupt_action])

        menu_args.extend(["", "", ""])  # Separator
        menu_args.extend(["Close", "q", ""])

        subprocess.run(["tmux", "display-menu"] + menu_args)
    except Exception as e:
        subprocess.run(["tmux", "display-message", f"Error: {e}"])


def check_attention_and_notify():
    """Check if any agents need attention and trigger bell if so."""
    try:
        if not tmux_has_sessions():
            return

        status, count, attention = get_global_agent_status()
        if attention:
            try:
                out = subprocess.check_output(
                    ["tmux", "show-environment", "-g", "TMUX_AGENT_LAST_ATTENTION"],
                    text=True, stderr=subprocess.DEVNULL,
                ).strip().split("=")[1]
                last_attention = int(out)
            except Exception:
                last_attention = 0

            if len(attention) > last_attention:
                subprocess.run(["tmux", "run-shell", "-b", "printf '\\a'"])
                subprocess.run([
                    "tmux", "set-environment", "-g",
                    "TMUX_AGENT_LAST_ATTENTION", str(len(attention)),
                ])
        else:
            subprocess.run([
                "tmux", "set-environment", "-g",
                "TMUX_AGENT_LAST_ATTENTION", "0",
            ], stderr=subprocess.DEVNULL)
    except Exception:
        pass


if __name__ == "__main__":
    import sys

    if len(sys.argv) > 1:
        if sys.argv[1] == "--status":
            print_global_status()
        elif sys.argv[1] == "--menu":
            run_menu()
        elif sys.argv[1] == "--menu-cmd":
            cmd = generate_menu_command(get_all_agents_info())
            if cmd:
                print(cmd)
            else:
                print('display-message "No AI agents running"')
        elif sys.argv[1] == "--check-attention":
            check_attention_and_notify()
    else:
        main()
