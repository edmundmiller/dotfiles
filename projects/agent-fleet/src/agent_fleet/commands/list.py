"""List command for agent-fleet."""

import typer
from datetime import datetime
from rich.console import Console
from rich.table import Table

from agent_fleet.core.state import load_state
from agent_fleet.core.workspace import get_repo_root, list_jj_workspaces

app = typer.Typer()
console = Console()


@app.command(name="list")
def list_workspaces():
    """
    List all active agent workspaces.

    Shows workspace name, description, creation time, and path.
    """
    repo_root = get_repo_root()
    state = load_state(repo_root)

    if not state["workspaces"]:
        console.print("[yellow]No active workspaces[/yellow]")
        return

    # Get actual jj workspaces to check if they still exist
    jj_workspaces = list_jj_workspaces()

    table = Table(title="Agent Fleet Workspaces")
    table.add_column("Workspace", style="cyan")
    table.add_column("Description", style="white")
    table.add_column("Created", style="dim")
    table.add_column("Status", style="green")

    for name, info in sorted(state["workspaces"].items()):
        # Check if workspace still exists in jj
        exists = name in jj_workspaces
        status = "✓ Active" if exists else "⚠ Missing"
        status_style = "green" if exists else "yellow"

        created = datetime.fromisoformat(info["created"])
        created_str = created.strftime("%Y-%m-%d %H:%M")

        table.add_row(
            name,
            info["description"][:50] + ("..." if len(info["description"]) > 50 else ""),
            created_str,
            f"[{status_style}]{status}[/{status_style}]",
        )

    console.print(table)
