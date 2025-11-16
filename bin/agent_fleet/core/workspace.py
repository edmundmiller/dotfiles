"""JJ workspace operations for agent-fleet."""

import subprocess
import sys
from pathlib import Path
import typer
from rich.console import Console

from agent_fleet.core.config import WORKSPACE_PREFIX

console = Console()


def get_repo_root() -> Path:
    """Get the repository root directory."""
    try:
        result = subprocess.run(
            ["jj", "workspace", "root"],
            capture_output=True,
            text=True,
            check=True,
        )
        return Path(result.stdout.strip())
    except subprocess.CalledProcessError as e:
        console.print("[red]Error: Not in a jj repository[/red]", file=sys.stderr)
        console.print(f"[dim]{e.stderr}[/dim]", file=sys.stderr)
        raise typer.Exit(1)


def create_workspace(name: str, path: Path) -> bool:
    """Create a new jj workspace."""
    try:
        subprocess.run(
            ["jj", "workspace", "add", "--name", name, str(path)],
            check=True,
            capture_output=True,
        )
        return True
    except subprocess.CalledProcessError as e:
        console.print("[red]Error creating workspace:[/red]", file=sys.stderr)
        console.print(f"[dim]{e.stderr.decode()}[/dim]", file=sys.stderr)
        return False


def forget_workspace(name: str) -> bool:
    """Forget a jj workspace."""
    try:
        subprocess.run(
            ["jj", "workspace", "forget", name],
            check=True,
            capture_output=True,
        )
        return True
    except subprocess.CalledProcessError as e:
        console.print("[yellow]Warning: Could not forget workspace:[/yellow]")
        console.print(f"[dim]{e.stderr.decode()}[/dim]")
        return False


def list_jj_workspaces() -> set[str]:
    """Get list of all jj workspaces."""
    try:
        result = subprocess.run(
            ["jj", "workspace", "list"],
            capture_output=True,
            text=True,
            check=True,
        )
        # Parse output to get workspace names
        workspaces = set()
        for line in result.stdout.strip().split("\n"):
            # Format: "workspace_name: /path/to/workspace"
            if ":" in line:
                name = line.split(":")[0].strip().lstrip("*").strip()
                if name.startswith(WORKSPACE_PREFIX):
                    workspaces.add(name)
        return workspaces
    except subprocess.CalledProcessError:
        return set()
