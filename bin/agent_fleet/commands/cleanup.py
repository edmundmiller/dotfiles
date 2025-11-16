"""Cleanup command for agent-fleet."""

import shutil
import sys
import typer
from typing import Optional
from rich.console import Console

from agent_fleet.core.config import WORKTREES_DIR
from agent_fleet.core.state import load_state, save_state
from agent_fleet.core.workspace import get_repo_root, forget_workspace

app = typer.Typer()
console = Console()


@app.command()
def cleanup(
    workspace_name: Optional[str] = typer.Argument(
        None, help="Workspace name to clean up (e.g., agent-20250116-123456)"
    ),
    all: bool = typer.Option(False, "--all", help="Clean up all agent workspaces"),
    force: bool = typer.Option(False, "--force", "-f", help="Skip confirmation"),
):
    """
    Clean up agent workspaces.

    Removes workspace from jj and deletes the directory.
    Use --all to clean up all workspaces, or specify a workspace name.
    """
    repo_root = get_repo_root()
    state = load_state(repo_root)

    if not workspace_name and not all:
        console.print(
            "[red]Error: Specify a workspace name or use --all[/red]", file=sys.stderr
        )
        raise typer.Exit(1)

    # Determine which workspaces to clean
    if all:
        workspaces_to_clean = list(state["workspaces"].keys())
        if not workspaces_to_clean:
            console.print("[yellow]No workspaces to clean[/yellow]")
            return

        if not force:
            console.print(
                f"[yellow]About to clean up {len(workspaces_to_clean)} workspaces:[/yellow]"
            )
            for name in workspaces_to_clean:
                console.print(f"  - {name}")
            if not typer.confirm("Continue?"):
                raise typer.Abort()
    else:
        if workspace_name not in state["workspaces"]:
            console.print(
                f"[yellow]Warning: Workspace '{workspace_name}' not in state file[/yellow]"
            )
            console.print("[dim]Attempting cleanup anyway...[/dim]")
        workspaces_to_clean = [workspace_name]

    # Clean up each workspace
    for name in workspaces_to_clean:
        console.print(f"[cyan]Cleaning up:[/cyan] {name}")

        # Forget workspace in jj
        forget_workspace(name)

        # Remove directory
        if name in state["workspaces"]:
            workspace_path = repo_root / state["workspaces"][name]["path"]
        else:
            workspace_path = repo_root / WORKTREES_DIR / name

        if workspace_path.exists():
            try:
                shutil.rmtree(workspace_path)
                console.print(f"[green]✓[/green] Removed directory: {workspace_path}")
            except Exception as e:
                console.print(f"[red]Error removing directory:[/red] {e}")
        else:
            console.print("[dim]Directory already removed[/dim]")

        # Remove from state
        if name in state["workspaces"]:
            del state["workspaces"][name]

    # Save updated state
    save_state(repo_root, state)
    console.print(
        f"[green]✓[/green] Cleaned up {len(workspaces_to_clean)} workspace(s)"
    )
