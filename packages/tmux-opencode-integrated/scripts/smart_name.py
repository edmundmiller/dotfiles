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
DIR_PROGRAMS = ["nvim", "vim", "vi", "git", "jjui", "opencode", "claude", "amp"]
MAX_NAME_LEN = 24
USE_TILDE = True

ICON_IDLE = "□"
ICON_BUSY = "●"
ICON_WAITING = "■"
ICON_ERROR = "▲"
ICON_UNKNOWN = "◇"

# Colored versions for tmux display-menu (using tmux style syntax)
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


def colorize_status_icon(status):
    """Return the status icon with tmux color formatting for window names."""
    return ICON_TO_COLOR.get(status, status)


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


def strip_ansi_and_control(text):
    """Remove ANSI escape sequences and control characters from text."""
    # Remove ANSI escape sequences (colors, cursor movement, etc.)
    text = re.sub(r'\x1b\[[0-9;]*[a-zA-Z]', '', text)
    text = re.sub(r'\x1b\][^\x07]*\x07', '', text)  # OSC sequences
    text = re.sub(r'\x1b[PX^_][^\x1b]*\x1b\\', '', text)  # DCS/PM/APC/SOS
    # Remove other control characters (except newline/tab)
    text = re.sub(r'[\x00-\x08\x0b\x0c\x0e-\x1f\x7f-\x9f]', '', text)
    return text


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

    # Strip ANSI/control sequences for cleaner pattern matching
    content = strip_ansi_and_control(content)

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

    # Waiting patterns - agent permission/approval prompts (needs user action)
    # More specific to avoid matching arbitrary [Y/n] prompts
    waiting_patterns = [
        r"Allow (?:once|always)\?",  # Claude permission prompt
        r"Do you want to (?:run|execute|allow)",  # Generic agent prompts
        r"(?:Approve|Confirm|Accept)\?.*\[Y/n\]",
        r"Press enter to continue",  # Agent paused
        r"Waiting for (?:input|approval|confirmation)",
        r"Permission required",  # OpenCode permission prompt
        r"(?:yes|no|skip)\s*›",  # OpenCode choice prompt
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
        r"Calling tool",  # Amp tool execution
        r"Tool:",  # Claude tool header
        r"⎿",  # Claude output marker (indicates response in progress)
        r"Running tools",  # Amp "Running tools..." message
        r"≋",  # Amp activity indicator (wavy lines)
        r"■■■",  # OpenCode progress bar (filled squares)
        r"esc interrupt",  # OpenCode/agent actively running (can be interrupted)
        r"Esc to cancel",  # Amp/Claude actively running (can be cancelled)
    ]
    if any(re.search(p, content, re.IGNORECASE) for p in busy_patterns):
        return ICON_BUSY

    # Idle patterns - agent is ready for user input (positive detection)
    # These indicate the agent has finished and is waiting for a new prompt
    idle_patterns = [
        r">\s*$",  # Input prompt at end of content (opencode/claude/amp)
        r"❯\s*$",  # Alternative prompt character
        r"│\s*$",  # Amp/Claude input box border at end
        r"What would you like",  # Common agent ready message
        r"How can I help",  # Agent ready prompt
        r"Session went idle",  # OpenCode explicit idle message
        r"Finished\s*$",  # Task completion indicator
        r"Done\.\s*$",  # Simple completion indicator
        r"completed successfully",  # Success message
        r"\d+% of \d+k",  # Amp context usage display (visible when idle)
        r"OpenCode \d+\.\d+\.\d+",  # OpenCode version in status bar (visible when idle)
        r"ctrl\+p commands",  # OpenCode status bar (visible when idle)
    ]
    if any(re.search(p, content, re.IGNORECASE | re.MULTILINE) for p in idle_patterns):
        return ICON_IDLE

    return ICON_UNKNOWN


AGENT_PROGRAMS = ["opencode", "claude", "amp"]


def get_pane_program(pane):
    """Get the program running in a pane."""
    pane_cmd = pane_value(pane, "pane_current_command", "")
    pane_pid = pane_value(pane, "pane_pid", "")

    # If pane_current_command is already a known agent, use it directly
    # (pane_pid points to the shell, not the agent process)
    if pane_cmd in AGENT_PROGRAMS:
        return pane_cmd

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
    """Find all panes in a window running AI agents (opencode, claude, amp)."""
    agent_panes = []
    for pane in window.panes:
        program = get_pane_program(pane)
        if program in AGENT_PROGRAMS:
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
                        # Window has agent(s) - show colored status icon
                        colored_icon = colorize_status_icon(agent_status)
                        if program in AGENT_PROGRAMS:
                            # Active pane is the agent - show path
                            display_path = path or base_name or program
                            new_name = f"{colored_icon} {display_path}"
                        else:
                            # Agent in background pane - show base name + indicator
                            new_name = f"{colored_icon} {base_name}"
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


def get_all_agents_info(server):
    """Get detailed info for all agents across all sessions.
    
    Returns list of dicts with: session, window, pane_id, program, status, path
    """
    agents = []
    
    for session in server.sessions:
        try:
            session_name = session.name
        except Exception:
            session_name = "?"
            
        for window in session.windows:
            try:
                window_index = window.index
                window_name = window.name
            except Exception:
                window_index = "?"
                window_name = "?"
                
            agent_panes = find_agent_panes(window)
            for pane, program in agent_panes:
                status = get_opencode_status(pane)
                pane_path = pane_value(pane, "pane_current_path", "")
                pane_id = pane_value(pane, "pane_id", "")
                
                agents.append({
                    "session": session_name,
                    "window_index": window_index,
                    "window_name": window_name,
                    "pane_id": pane_id,
                    "program": program,
                    "status": status,
                    "path": format_path(pane_path),
                })
    
    return agents


def generate_menu_command(agents):
    """Generate a tmux display-menu command for agent management.
    
    Menu format:
    - Header showing agent count and aggregate status
    - List of agents with status icon, program, session:window
    - Each agent is selectable to jump to that pane
    """
    if not agents:
        return None
    
    # Sort by priority: error/unknown/waiting first, then by session/window
    priority = {ICON_ERROR: 0, ICON_UNKNOWN: 1, ICON_WAITING: 2, ICON_BUSY: 3, ICON_IDLE: 4}
    agents_sorted = sorted(agents, key=lambda a: (priority.get(a["status"], 5), a["session"], a["window_index"]))
    
    # Build menu items
    menu_items = []
    
    # Header
    statuses = [a["status"] for a in agents]
    aggregate = prioritize_status(statuses)
    count = len(agents)
    attention_count = sum(1 for s in statuses if s in (ICON_ERROR, ICON_UNKNOWN, ICON_WAITING))
    
    if attention_count > 0:
        header = f"{aggregate} {count} agents ({attention_count} need attention)"
    else:
        header = f"{aggregate} {count} agents"
    
    menu_items.append(f'"{header}" "" ""')
    menu_items.append('"-" "" ""')  # Separator
    
    # Agent entries
    for i, agent in enumerate(agents_sorted):
        status = agent["status"]
        program = agent["program"]
        session = agent["session"]
        window_idx = agent["window_index"]
        pane_id = agent["pane_id"]
        path = agent["path"]
        
        # Truncate path if too long
        if path and len(path) > 20:
            path = "..." + path[-17:]
        
        # Label: "● opencode session:1 ~/project"
        label = f"{status} {program} {session}:{window_idx}"
        if path:
            label += f" {path}"
        
        # Key: first letter of program or number
        if i < 9:
            key = str(i + 1)
        else:
            key = ""
        
        # Action: switch to session and window, then select pane
        if pane_id:
            action = f"switch-client -t {session}:{window_idx} ; select-pane -t {pane_id}"
        else:
            action = f"switch-client -t {session}:{window_idx}"
        
        menu_items.append(f'"{label}" "{key}" "{action}"')
    
    # Footer
    menu_items.append('"-" "" ""')
    menu_items.append('"Refresh" "r" "run-shell -b \\\"#{TMUX_OPENCODE_MENU_CMD}\\\""')
    menu_items.append('"Close" "q" ""')
    
    # Build the full command
    # Position: C = center
    items_str = " ".join(menu_items)
    return f'display-menu -T "Agent Management" -x C -y C {items_str}'


def print_menu():
    """Print the tmux display-menu command for agent management."""
    if libtmux is None:
        print('display-message "libtmux not available"')
        return
    
    try:
        server = libtmux.Server()
        if not server.children:
            print('display-message "No tmux sessions"')
            return
        
        agents = get_all_agents_info(server)
        if not agents:
            print('display-message "No AI agents running"')
            return
        
        cmd = generate_menu_command(agents)
        if cmd:
            print(cmd)
        else:
            print('display-message "No AI agents running"')
    except Exception as e:
        print(f'display-message "Error: {e}"')


def run_menu():
    """Execute the agent management menu directly."""
    if libtmux is None:
        return
    
    try:
        server = libtmux.Server()
        if not server.children:
            subprocess.run(["tmux", "display-message", "No tmux sessions"])
            return
        
        agents = get_all_agents_info(server)
        if not agents:
            subprocess.run(["tmux", "display-message", "No AI agents running"])
            return
        
        # Build menu items for direct execution
        # -C 1 starts selection on first agent (skipping header)
        menu_args = ["-T", "Agent Management", "-x", "C", "-y", "C", "-C", "1"]
        
        # Sort by priority
        priority = {ICON_ERROR: 0, ICON_UNKNOWN: 1, ICON_WAITING: 2, ICON_BUSY: 3, ICON_IDLE: 4}
        agents_sorted = sorted(agents, key=lambda a: (priority.get(a["status"], 5), a["session"], a["window_index"]))
        
        # Header
        statuses = [a["status"] for a in agents]
        aggregate = prioritize_status(statuses)
        count = len(agents)
        attention_count = sum(1 for s in statuses if s in (ICON_ERROR, ICON_UNKNOWN, ICON_WAITING))
        
        # Header - just use aggregate icon with color (not disabled, but -C 1 skips it)
        aggregate_color = ICON_TO_COLOR.get(aggregate, aggregate)
        if attention_count > 0:
            header = f"{aggregate_color} {count} agents ({attention_count} need attention)"
        else:
            header = f"{aggregate_color} {count} agents"
        
        menu_args.extend([header, "", ""])
        menu_args.extend(["", "", ""])  # Separator
        
        # Agent entries
        for i, agent in enumerate(agents_sorted):
            status = agent["status"]
            status_color = ICON_TO_COLOR.get(status, status)
            program = agent["program"]
            session = agent["session"]
            window_idx = agent["window_index"]
            pane_id = agent["pane_id"]
            path = agent["path"]
            
            # Truncate path if too long
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
        
        # Footer
        menu_args.extend(["", "", ""])  # Separator
        menu_args.extend(["Close", "q", ""])
        
        subprocess.run(["tmux", "display-menu"] + menu_args)
    except Exception as e:
        subprocess.run(["tmux", "display-message", f"Error: {e}"])


if __name__ == "__main__":
    import sys
    
    if len(sys.argv) > 1:
        if sys.argv[1] == "--status":
            print_global_status()
        elif sys.argv[1] == "--menu":
            run_menu()
        elif sys.argv[1] == "--menu-cmd":
            print_menu()
    else:
        main()
