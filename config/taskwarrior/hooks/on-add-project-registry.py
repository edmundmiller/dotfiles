#!/usr/bin/env python3
"""
TaskWarrior on-add hook: Auto-register projects in the project registry.

When a task is added with a project field, this hook checks if the project
exists in the projects.sqlite3 database. If not, it auto-creates an entry
with sensible defaults.
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
    # Read the task from stdin
    task_json = sys.stdin.readline()
    task = json.loads(task_json)

    # Output the task unchanged
    print(json.dumps(task))

    # Check if task has a project
    project_name = task.get("project")
    if not project_name:
        sys.exit(0)

    # Get workspace from task (prefer time_map as it's explicitly set, workspace has a default)
    workspace = task.get("time_map") or task.get("workspace")

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
