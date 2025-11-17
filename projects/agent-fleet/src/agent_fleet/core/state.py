"""State management for agent-fleet."""

import json
from datetime import datetime
from pathlib import Path
from rich.console import Console

from agent_fleet.core.config import STATE_FILE, WORKTREES_DIR

console = Console()


def load_state(repo_root: Path) -> dict:
    """Load state from JSON file."""
    state_path = repo_root / STATE_FILE
    if state_path.exists():
        try:
            return json.loads(state_path.read_text())
        except json.JSONDecodeError:
            console.print(
                "[yellow]Warning: Invalid state file, starting fresh[/yellow]"
            )
    return {"workspaces": {}}


def save_state(repo_root: Path, state: dict):
    """Save state to JSON file."""
    state_path = repo_root / STATE_FILE
    state_path.write_text(json.dumps(state, indent=2))


def generate_task_id() -> str:
    """Generate a unique task ID."""
    return datetime.now().strftime("%Y%m%d-%H%M%S")


def ensure_worktrees_dir(repo_root: Path) -> Path:
    """Ensure .worktrees directory exists."""
    worktrees = repo_root / WORKTREES_DIR
    worktrees.mkdir(exist_ok=True)
    return worktrees
