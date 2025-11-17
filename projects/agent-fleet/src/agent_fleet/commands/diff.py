"""Diff command for agent-fleet (stub)."""

import typer
from rich.console import Console

app = typer.Typer()
console = Console()


@app.command(epilog="Made with :heart: by the agent-fleet crew")
def diff(
    workspace_name: str = typer.Argument(
        ..., help="Workspace name to show diff for (e.g., agent-20250116-123456)"
    ),
):
    """
    Show diff of changes in a workspace.

    Displays the changes made in the specified workspace compared to the
    parent commit. This is useful for reviewing agent work before merging
    or cleaning up.

    Future implementation will:
    - Run `jj diff -r <workspace>@` to get changes
    - Display with syntax highlighting
    - Support different diff formats (unified, side-by-side)
    - Allow filtering by file path
    """
    console.print(
        "[yellow]⚠ Coming soon![/yellow] The diff command is not yet implemented."
    )
    console.print("\n[dim]Planned features:[/dim]")
    console.print("  • View changes made by the agent")
    console.print("  • Syntax-highlighted diff output")
    console.print("  • Filter by file path")
    console.print("  • Multiple diff formats\n")
    raise typer.Exit(1)
