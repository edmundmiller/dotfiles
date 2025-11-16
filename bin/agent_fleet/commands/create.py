"""Create command for agent-fleet."""

import os
import typer
from datetime import datetime
from rich.console import Console

from agent_fleet.core.config import WORKSPACE_PREFIX
from agent_fleet.core.state import (
    load_state,
    save_state,
    generate_task_id,
    ensure_worktrees_dir,
)
from agent_fleet.core.workspace import get_repo_root, create_workspace
from agent_fleet.core.obsidian import create_task_note

app = typer.Typer()
console = Console()


@app.command()
def create(
    description: str = typer.Argument(..., help="Task description for the agent"),
    agent: str = typer.Option(
        "claude-code", "--agent", "-a", help="Agent command to run"
    ),
    auto_accept: bool = typer.Option(
        True, "--auto-accept/--no-auto-accept", help="Auto-accept agent edits"
    ),
):
    """
    Create a new workspace and launch an agent.

    Creates a JJ workspace in .worktrees/, saves the task metadata,
    creates a TaskNote in your Obsidian vault, and launches the
    specified agent with the task description.
    """
    repo_root = get_repo_root()
    worktrees_dir = ensure_worktrees_dir(repo_root)
    state = load_state(repo_root)

    # Generate task ID and paths
    task_id = generate_task_id()
    workspace_name = f"{WORKSPACE_PREFIX}{task_id}"
    workspace_path = worktrees_dir / workspace_name

    console.print(f"[cyan]Creating workspace:[/cyan] {workspace_name}")

    # Create workspace
    if not create_workspace(workspace_name, workspace_path):
        raise typer.Exit(1)

    # Save to state
    state["workspaces"][workspace_name] = {
        "id": task_id,
        "description": description,
        "created": datetime.now().isoformat(),
        "path": str(workspace_path.relative_to(repo_root)),
        "agent": agent,
    }
    save_state(repo_root, state)

    console.print(f"[green]✓[/green] Workspace created at: {workspace_path}")

    # Create TaskNote in Obsidian vault
    create_task_note(task_id, description, workspace_path, agent, repo_root)

    console.print(f"[cyan]Launching {agent}...[/cyan]\n")

    # Change to workspace directory
    os.chdir(workspace_path)

    # Build agent command
    agent_cmd = [agent]
    if auto_accept and agent == "claude-code":
        agent_cmd.append("--accept-edits")

    # Launch agent with the prompt
    # The script will exec and be replaced by the agent process
    os.execvp(agent_cmd[0], agent_cmd + [description])
