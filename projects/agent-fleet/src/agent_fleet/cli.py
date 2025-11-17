"""
Agent Fleet - Manage parallel JJ workspaces for AI coding agents

Usage:
    agent-fleet create "task description"    # Create workspace and launch claude
    agent-fleet list                         # Show active workspaces
    agent-fleet cleanup <workspace-name>     # Remove specific workspace
    agent-fleet cleanup --all                # Remove all agent workspaces
    agent-fleet diff <workspace-name>        # Show diff (coming soon)
    agent-fleet note <workspace-name>        # Manage notes (coming soon)
"""

import typer

# Import command modules
from agent_fleet.commands import create, list, cleanup, diff, note

# Create main app
app = typer.Typer(help="Manage parallel JJ workspaces for AI coding agents")

# Add commands at top level (flattened structure)
app.add_typer(create.app, name=None)
app.add_typer(list.app, name=None)
app.add_typer(cleanup.app, name=None)
app.add_typer(diff.app, name=None)
app.add_typer(note.app, name=None)


def main():
    """Entry point for the agent-fleet CLI."""
    app()


if __name__ == "__main__":
    main()
