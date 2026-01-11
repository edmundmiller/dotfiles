#!/usr/bin/env python3

import os
import re
import sys
import subprocess

try:
    import libtmux
except ImportError:
    # This allows the script to be edited/checked in environments without libtmux
    libtmux = None


def get_current_tmux_window_name(window):
    """Get window name using smart-name logic with program prefixes"""
    try:
        active_pane = window.active_pane
        if not active_pane:
            return ""

        pane_current_path = active_pane.get("pane_current_path", "")
        pane_current_command = active_pane.get("pane_current_command", "")

        # Define "dir programs" that should show directory
        dir_programs = [
            "bash",
            "zsh",
            "fish",
            "nvim",
            "vim",
            "vi",
            "git",
            "jjui",
            "claude",
            "opencode",
        ]

        # Calculate pretty path
        home = os.environ.get("HOME", "")
        if pane_current_path.startswith(home):
            path = pane_current_path.replace(home, "~", 1)
        else:
            path = pane_current_path

        # Shorten path if it's just home
        if path == "~" and pane_current_command == "zsh":
            path = "~"

        # If it's a dir program, show "program: path" (requested by user)
        if pane_current_command in dir_programs:
            # Don't show shell names, just the path
            if pane_current_command in ["bash", "zsh", "fish"]:
                return path
            # For others (nvim, git, etc), show prefix
            return f"{pane_current_command}: {path}"

        # Otherwise return the command name
        return pane_current_command
    except Exception:
        return "error"


def get_opencode_status(pane):
    """Detect OpenCode status by capturing pane content"""
    # Capture last 10 lines of pane content
    try:
        # Using capture_pane from libtmux
        # start=-10 captures last 10 lines
        cmd_output = pane.cmd("capture-pane", "-p", "-S", "-10").stdout
        if isinstance(cmd_output, list):
            content = "\n".join(cmd_output)
        else:
            content = str(cmd_output)
    except Exception:
        return None

    # Status Icons
    ICON_IDLE = "○"
    ICON_BUSY = "●"
    ICON_WAITING = "◉"
    ICON_ERROR = "✗"
    ICON_FINISHED = "✔"

    # Regex patterns (ported from bash script)
    # 1. Error detection
    if re.search(
        r"(Traceback|UnhandledPromiseRejection|FATAL ERROR)", content, re.IGNORECASE
    ):
        return ICON_ERROR

    # 2. Waiting for input
    if re.search(r"(\[Y/n\]|Allow once|Allow always|Reject)", content):
        return ICON_WAITING

    # 3. Busy indicators (spinners, thinking)
    if re.search(r"(Thinking\.\.\.|Running\.\.\.|Executing)", content, re.IGNORECASE):
        return ICON_BUSY

    # 4. Finished state
    return ICON_IDLE


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
                    active_pane = window.active_pane
                    if not active_pane:
                        continue

                    command = active_pane.get("pane_current_command")

                    # Base name logic
                    base_name = get_current_tmux_window_name(window)

                    # OpenCode detection
                    is_opencode = False

                    # Check command
                    if command in ["opencode", "oc", "node"]:
                        # For node, check if arguments contain opencode/oc
                        # This is harder with just libtmux, would need psutil or inspecting pane_cmd
                        # For now assume 'node' might be opencode if we see the UI
                        is_opencode = True

                    if is_opencode:
                        status_icon = get_opencode_status(active_pane)
                        # Format: "● OC | ~/dotfiles" (icon first)
                        # Use a default icon if detection failed
                        icon = status_icon if status_icon else "○"
                        new_name = f"{icon} OC | {base_name}"
                    else:
                        # Format: "~/dotfiles" or "nvim: ~/dotfiles"
                        new_name = base_name

                    # Apply name if changed
                    # Encode/decode handling for safety
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
