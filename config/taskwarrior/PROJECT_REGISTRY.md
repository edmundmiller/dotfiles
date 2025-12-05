# TaskWarrior Project Registry

A hook-based system for managing project metadata (start/end dates, status, workspace) in TaskWarrior.

## Overview

TaskWarrior treats projects as simple string attributes on tasks - there's no native way to store project-level metadata. This system extends TaskWarrior with:

- **Automatic project registration** via hooks when tasks are added/modified
- **Project metadata storage** in a SQLite database
- **CLI tool** (`tw-projects`) for managing project information

## Architecture

```
~/.local/share/task/
├── hooks/
│   ├── on-add-project-registry.py      # Auto-registers projects on task add
│   └── on-modify-project-registry.py   # Auto-registers projects on task modify
├── projects.sqlite3                     # Project metadata database
└── taskchampion.sqlite3                 # TaskWarrior task data (untouched)

~/.local/bin/
└── tw-projects                          # CLI for project management
```

## Installation

### 1. Create hooks directory

```bash
mkdir -p ~/.local/share/task/hooks
```

### 2. Install hooks

Copy or symlink the hook scripts:

```bash
# From dotfiles
ln -sf ~/.config/dotfiles/config/taskwarrior/hooks/on-add-project-registry.py ~/.local/share/task/hooks/
ln -sf ~/.config/dotfiles/config/taskwarrior/hooks/on-modify-project-registry.py ~/.local/share/task/hooks/

# Make executable
chmod +x ~/.local/share/task/hooks/*.py
```

### 3. Install CLI

```bash
# From dotfiles
ln -sf ~/.config/dotfiles/bin/tw-projects ~/.local/bin/tw-projects

# Or copy directly
cp ~/.config/dotfiles/bin/tw-projects ~/.local/bin/
chmod +x ~/.local/bin/tw-projects
```

### 4. Verify installation

```bash
# Check TaskWarrior sees the hooks
task diag | grep -A 5 "^Hooks"

# Should show:
# Hooks
#    System: Enabled
#    Location: /Users/emiller/.local/share/task/hooks
#    Active: on-add-project-registry.py    (executable)
#            on-modify-project-registry.py (executable)
```

### 5. Import existing projects

```bash
tw-projects import-existing
```

## CLI Usage

### List projects

```bash
# All projects
tw-projects list

# Filter by workspace
tw-projects list --workspace seqera

# Filter by status
tw-projects list --status active

# JSON output
tw-projects list --json
```

### Show project details

```bash
tw-projects show ai-cli.launch
```

### Set project metadata

```bash
# Set end date
tw-projects set ai-cli.launch --end 2025-12-15

# Set display name
tw-projects set ai-cli.launch --display-name "Seqera AI CLI/TUI v1.0 Launch"

# Set workspace
tw-projects set ai-cli.launch --workspace seqera

# Set multiple fields
tw-projects set ai-cli.launch \
  --end 2025-12-15 \
  --display-name "Seqera AI CLI/TUI v1.0 Launch" \
  --workspace seqera \
  --description "Initial public release of the AI CLI/TUI"

# Set start date
tw-projects set ai-cli.launch --start 2025-11-01

# Change status
tw-projects set ai-cli.launch --status planned
```

### Project lifecycle

```bash
# Mark as completed
tw-projects complete ai-cli.launch

# Mark as cancelled
tw-projects cancel some-project
```

### Timeline view

```bash
# Show all projects with end dates, ordered by deadline
tw-projects timeline

# Filter by workspace
tw-projects timeline --workspace seqera

# JSON output
tw-projects timeline --json
```

### Import and delete

```bash
# Import all existing projects from TaskWarrior
tw-projects import-existing

# Delete a project from registry (does not affect tasks)
tw-projects delete old-project

# Force delete without confirmation
tw-projects delete old-project --force
```

## Database Schema

The project registry uses SQLite with the following schema:

```sql
CREATE TABLE projects (
    name TEXT PRIMARY KEY,           -- e.g., "ai-cli.launch"
    display_name TEXT,               -- e.g., "Seqera AI CLI/TUI v1.0 Launch"
    workspace TEXT,                  -- e.g., "seqera", "personal"
    start_date TEXT,                 -- ISO date YYYY-MM-DD
    end_date TEXT,                   -- ISO date (deadline)
    status TEXT DEFAULT 'active',    -- active, completed, cancelled, planned
    description TEXT,
    created_at TEXT,
    updated_at TEXT
);
```

### Status values

| Status      | Description                         |
| ----------- | ----------------------------------- |
| `active`    | Currently being worked on (default) |
| `planned`   | Scheduled for future work           |
| `completed` | Successfully finished               |
| `cancelled` | Abandoned or no longer needed       |

### Direct database access

```bash
# Query the database directly
sqlite3 ~/.local/share/task/projects.sqlite3 "SELECT * FROM projects"

# Get projects ending this month
sqlite3 ~/.local/share/task/projects.sqlite3 \
  "SELECT name, end_date FROM projects
   WHERE end_date LIKE '2025-12%'
   ORDER BY end_date"
```

## Hook Behavior

### on-add-project-registry.py

When a task is added:

1. Reads task JSON from stdin
2. Outputs task JSON unchanged (pass-through)
3. If task has a `project` field:
   - Checks if project exists in database
   - If new: creates entry with auto-generated defaults
     - `display_name`: Title-cased, dots/dashes→spaces
     - `workspace`: From task's `time_map` or `workspace` UDA
     - `status`: `'active'`
4. Prints feedback: "New project registered: {name}"

### on-modify-project-registry.py

When a task is modified:

1. Reads original + modified task JSON from stdin
2. Outputs modified task JSON unchanged
3. If project changed to a new value:
   - Same registration logic as on-add
4. If project unchanged: no action

## Project Naming Conventions

Projects can use any naming scheme:

```bash
# Flat names
PhD-Dissertation
Seqera-Work

# Hierarchical (dot-separated)
ai-cli.launch
nebius.webinar
mlflow.nims

# GitHub-style
seqeralabs/web
nf-core/tools
```

The display name is auto-generated from the project name:

- `ai-cli.launch` → "Ai Cli Launch"
- `PhD-Dissertation` → "Phd Dissertation"
- `seqeralabs/web` → "Seqeralabs/Web"

Override with `--display-name` for better formatting.

## Future: Migration to TaskChampion DB

Currently the project registry uses a separate SQLite database. To migrate into the main TaskChampion database:

```bash
# Export current projects
sqlite3 ~/.local/share/task/projects.sqlite3 ".dump projects" > projects_backup.sql

# Create table in TaskChampion (after backing up!)
sqlite3 ~/.task/taskchampion.sqlite3 < projects_backup.sql
```

**Note:** This requires careful testing as it modifies TaskWarrior's internal database.

## Troubleshooting

### Hooks not running

```bash
# Check hooks are enabled
task _get rc.hooks

# Check hook location
task diag | grep -A 5 Hooks

# Test hook manually
echo '{"description":"test","project":"test.project"}' | \
  python3 ~/.local/share/task/hooks/on-add-project-registry.py
```

### Database issues

```bash
# Check database exists
ls -la ~/.local/share/task/projects.sqlite3

# Verify schema
sqlite3 ~/.local/share/task/projects.sqlite3 ".schema"

# Check for data
sqlite3 ~/.local/share/task/projects.sqlite3 "SELECT COUNT(*) FROM projects"
```

### Debug hook execution

```bash
# Enable hook debugging
task rc.debug.hooks=2 add "Test task" project:test.debug

# This shows input/output/timing for each hook
```

## Dependencies

- Python 3.11+
- [uv](https://github.com/astral-sh/uv) (for CLI script)
- typer (auto-installed by uv)
- rich (auto-installed by uv)
