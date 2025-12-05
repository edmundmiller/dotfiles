#!/usr/bin/env python3
"""
TaskWarrior on-modify hook: Auto-register projects in the project registry.

When a task is modified and has a project field (new or changed), this hook
checks if the project exists in the projects.sqlite3 database. If not, it
auto-creates an entry with sensible defaults.
"""

import json
import os
import sqlite3
import sys
from datetime import datetime
from pathlib import Path

# Database location - same directory as TaskWarrior data
DB_PATH = (
    Path(os.environ.get("TASK_DATA", Path.home() / ".local/share/task"))
    / "projects.sqlite3"
)


def init_db(conn: sqlite3.Connection) -> None:
    """Initialize the database schema if it doesn't exist."""
    conn.execute("""
        CREATE TABLE IF NOT EXISTS projects (
            name TEXT PRIMARY KEY,
            display_name TEXT,
            workspace TEXT,
            start_date TEXT,
            end_date TEXT,
            status TEXT DEFAULT 'active',
            description TEXT,
            created_at TEXT DEFAULT (datetime('now')),
            updated_at TEXT DEFAULT (datetime('now'))
        )
    """)
    conn.execute(
        "CREATE INDEX IF NOT EXISTS idx_projects_workspace ON projects(workspace)"
    )
    conn.execute("CREATE INDEX IF NOT EXISTS idx_projects_status ON projects(status)")
    conn.execute(
        "CREATE INDEX IF NOT EXISTS idx_projects_end_date ON projects(end_date)"
    )
    conn.commit()


def humanize_project_name(name: str) -> str:
    """Convert project name to display name.

    Examples:
        ai-cli.launch -> Ai Cli Launch
        nebius.webinar -> Nebius Webinar
        PhD-Dissertation -> Phd Dissertation
    """
    # Replace dots, dashes, underscores with spaces
    display = name.replace(".", " ").replace("-", " ").replace("_", " ")
    # Title case
    return display.title()


def register_project(
    conn: sqlite3.Connection, project_name: str, workspace: str | None
) -> bool:
    """Register a new project if it doesn't exist.

    Returns True if a new project was created.
    """
    cursor = conn.execute("SELECT 1 FROM projects WHERE name = ?", (project_name,))
    if cursor.fetchone():
        return False  # Project already exists

    display_name = humanize_project_name(project_name)
    now = datetime.now().isoformat()

    conn.execute(
        """
        INSERT INTO projects (name, display_name, workspace, status, created_at, updated_at)
        VALUES (?, ?, ?, 'active', ?, ?)
    """,
        (project_name, display_name, workspace, now, now),
    )
    conn.commit()
    return True


def main() -> None:
    # on-modify receives TWO lines: original task, then modified task
    original_json = sys.stdin.readline()
    modified_json = sys.stdin.readline()

    # Parse both
    original = json.loads(original_json)
    modified = json.loads(modified_json)

    # Output the modified task unchanged
    print(json.dumps(modified))

    # Check if modified task has a project
    project_name = modified.get("project")
    if not project_name:
        sys.exit(0)

    # Only register if project is new or changed
    original_project = original.get("project")
    if project_name == original_project:
        # Project unchanged, no need to check
        sys.exit(0)

    # Get workspace from task (prefer time_map as it's explicitly set, workspace has a default)
    workspace = modified.get("time_map") or modified.get("workspace")

    # Connect to database and ensure schema exists
    conn = sqlite3.connect(DB_PATH)
    try:
        init_db(conn)

        # Register project if new
        if register_project(conn, project_name, workspace):
            print(f"New project registered: {project_name}")
    finally:
        conn.close()

    sys.exit(0)


if __name__ == "__main__":
    main()
