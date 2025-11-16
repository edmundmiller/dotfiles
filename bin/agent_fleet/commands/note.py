"""Note command for agent-fleet (stub)."""

import typer
from rich.console import Console

app = typer.Typer()
console = Console()


@app.command(epilog="Made with :heart: by the agent-fleet crew")
def note(
    workspace_name: str = typer.Argument(
        ..., help="Workspace name to manage note for (e.g., agent-20250116-123456)"
    ),
    action: str = typer.Option(
        "view",
        "--action",
        "-a",
        help="Action to perform: view, update",
    ),
):
    """
    View or update TaskNotes in Obsidian vault.

    TaskNotes are automatically created when you run 'agent-fleet create'.
    This command lets you view or update existing notes.

    Note location: ~/sync/claude-vault/00_Inbox/Agents/

    Future implementation will:
    - Open note in default editor (view)
    - Update note status (mark complete, add notes)
    - Show note preview in terminal

    Actions:
    - view: Open note in default editor
    - update: Update note status or add notes
    """
    console.print(
        "[yellow]⚠ Coming soon![/yellow] The note command is not yet implemented."
    )
    console.print("\n[dim]Planned features:[/dim]")
    console.print("  • Open TaskNote in editor")
    console.print("  • Update task status")
    console.print("  • Add notes and observations")
    console.print("  • Preview note in terminal\n")
    console.print(
        "[dim]Note: TaskNotes are auto-created with 'agent-fleet create'[/dim]\n"
    )
    raise typer.Exit(1)
