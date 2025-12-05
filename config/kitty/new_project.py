#!/usr/bin/env python3
"""
Custom kitten for creating new project-based tabs in kitty.
Inspired by andrew.hau.st's approach.

Usage:
  - Ctrl+Alt+1: Create single-window project tab
  - Ctrl+Alt+2: Create 2-window project tab (editor + shell)
  - Ctrl+Alt+3: Create 3-window project tab (editor + shell + logs)
"""

from kitty.boss import Boss
from kittens.tui.handler import result_handler
import subprocess
import os


def main(args):
    pass


@result_handler(no_ui=True)
def handle_result(args, answer, target_window_id, boss: Boss):
    """Handle the result and create new project tab."""

    # Get project directory (could integrate with autojump/zoxide)
    # For now, use current directory
    cwd = os.getcwd()

    # Parse layout type from args (1, 2, or 3 windows)
    layout_type = int(args[1]) if len(args) > 1 else 2

    # Create new tab
    tab = boss.active_tab

    if layout_type == 1:
        # Single window
        boss.new_tab_with_cwd()

    elif layout_type == 2:
        # Editor + Shell (vertical split)
        boss.new_tab_with_cwd()
        boss.launch("--cwd", "current", "--location", "vsplit", "--title", "Shell")

    elif layout_type == 3:
        # Editor + Shell + Logs (complex split)
        boss.new_tab_with_cwd()
        boss.launch("--cwd", "current", "--location", "vsplit", "--title", "Shell")
        boss.launch(
            "--cwd",
            "current",
            "--location",
            "hsplit",
            "--bias",
            "30",
            "--title",
            "Logs",
        )
