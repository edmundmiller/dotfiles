"""Obsidian TaskNote integration for agent-fleet."""

from datetime import datetime
from pathlib import Path
from rich.console import Console

console = Console()


def create_task_note(
    task_id: str, description: str, workspace_path: Path, agent: str, repo_root: Path
) -> bool:
    """
    Create a TaskNote in Obsidian vault for tracking agent work.

    Returns True if note was created successfully, False otherwise.
    """
    vault_path = Path.home() / "sync" / "claude-vault" / "00_Inbox" / "Agents"

    # Check if vault exists
    if not vault_path.exists():
        console.print(
            f"[yellow]Warning: Obsidian vault not found at {vault_path}[/yellow]"
        )
        console.print("[dim]Skipping TaskNote creation[/dim]")
        return False

    # Create agents directory if it doesn't exist
    vault_path.mkdir(parents=True, exist_ok=True)

    # Create note file
    note_path = vault_path / f"agent-{task_id}.md"
    created_time = datetime.now().isoformat()
    relative_workspace = workspace_path.relative_to(repo_root)

    note_content = f"""---
task_id: {task_id}
created: {created_time}
agent: {agent}
status: running
workspace: {relative_workspace}
---

# {description}

## Workspace
`{relative_workspace}`

## Notes
(Agent work tracked here)
"""

    try:
        note_path.write_text(note_content)
        console.print(f"[green]✓[/green] TaskNote created: {note_path.name}")
        return True
    except Exception as e:
        console.print(f"[yellow]Warning: Could not create TaskNote:[/yellow] {e}")
        return False
