# Bugwarrior Integration

This dotfiles configuration includes bugwarrior setup for syncing issues from Jira, GitHub, Linear, and Apple Reminders into Taskwarrior, with secure credential management via 1Password.

## Overview

Bugwarrior automatically pulls issues from:
- **Seqera Jira** - Assigned/reported issues with priority mapping
- **Linear** - Work tasks from Linear
- **GitHub** - Issues and PRs from multiple workspaces (nf-core, seqera, personal, phd)
- **Apple Reminders** - Personal reminders
- **1Password Integration** - Secure credential storage

## Quick Setup

### 1. Install & Configure
```bash
# Install bugwarrior
uv tool install bugwarrior

# Set up 1Password credentials (if needed)
setup-bugwarrior-credentials

# Configure taskwarrior UDAs
setup-bugwarrior
```

### 2. Test the Setup
```bash
# Dry run (safe test)
bugwarrior-pull --dry-run

# First real sync
bugwarrior-pull
```

## Configuration Details

### Services Configured

1. **Apple Reminders** (`my_reminders`)
   - Syncs from "Reminders" list
   - Workspace: `personal`

2. **Linear** (`work_linear`)
   - Assigned issues with unstarted/started status
   - Imports labels as tags
   - Workspace: `family`

3. **Seqera Jira** (`seqera_jira`)
   - URL: `https://seqera.atlassian.net`
   - Query: Assigned to you OR reported by you, unresolved
   - Priority: Maps Jira priority to Taskwarrior (High→H, Medium→M, Low→L)
   - Imports labels and sprints as tags
   - Project: Uses Jira project key (e.g., `PLAT`, `WAVE`)
   - Tags: `jira`, `bw`
   - Workspace: `seqera`

4. **GitHub** (8 targets: issues + PRs for each workspace)
   - **nf-core**: `nf-core`, `bioinformaticsorphanage`, `bioconda` orgs
   - **seqera**: `nextflow-io`, `seqeralabs`, `seqera-services` orgs
   - **personal**: `edmundmiller` user, `BioJulia` org
   - **phd**: `Functional-Genomics-Lab` org
   - Tags: `github`, `bw`, `assigned` (+ `PR` for pull requests)

### 1Password Items Required

| Service | Vault | Item | Fields |
|---------|-------|------|--------|
| Jira | Work | `Bugwarrior Jira` | `username`, `credential` |
| Linear | Private | `Linear Bugwarrior` | `credential` |
| GitHub | Private | `GitHub Personal Access Token` | `token` |

### Taskwarrior Integration

Bugwarrior creates User Defined Attributes (UDAs) in Taskwarrior:

#### Jira Fields
- `jiraid` - Issue ID (e.g., PLAT-123)
- `jirasummary` - Issue summary
- `jirastatus` - Current status
- `jiraurl` - Direct link to issue
- `jiracreatedts` - Creation timestamp

#### GitHub Fields
- `githubrepo` - Repository name
- `githubtitle` - Issue title
- `githuburl` - Direct link to issue
- `githubtype` - Issue or Pull Request

#### Linear Fields
- `linearid` - Issue ID
- `lineartitle` - Issue title
- `linearurl` - Direct link to issue

## Usage

### Shell Aliases (Zsh)

```bash
# Sync commands
bw              # Full sync (bugwarrior-pull)
bw-dry          # Dry run test

# View tasks by source
bw-tasks        # All bugwarrior tasks (+bw tag)
bw-linear       # Linear issues only
bw-github       # GitHub issues only

# Logs
bw-log          # View bugwarrior log
bw-errors       # View error log
```

### Direct Commands
```bash
# Manual sync
bugwarrior-pull

# Test configuration
bugwarrior-pull --dry-run

# Debug mode
bugwarrior-pull --dry-run --debug
```

### Taskwarrior Queries
```bash
# Show all imported issues
task +bw list

# Show by service
task +jira list
task +github list
task +linear list

# Show by workspace
task workspace:seqera list
task workspace:nfcore list
task workspace:personal list

# Show Jira issues by project
task project:PLAT list
task project:WAVE list
```

## File Locations

### Configuration
- **Main config**: `~/.config/dotfiles/config/bugwarrior/bugwarrior.toml`
- **Symlinked to**: `~/.config/bugwarrior/bugwarrior.toml`
- **Zsh aliases**: `~/.config/dotfiles/config/bugwarrior/aliases.zsh`

### Scripts
- `bin/setup-bugwarrior-credentials` - 1Password setup
- `bin/setup-bugwarrior` - Main configuration

## Customization

### Custom Jira Queries
Edit `config/bugwarrior/bugwarrior.toml`:

```toml
[seqera_jira]
# Example: Only specific projects
query = "project in (PLAT, WAVE) AND assignee = currentUser() AND resolution is null"

# Example: Include specific statuses
query = "assignee = currentUser() AND status in ('To Do', 'In Progress')"
```

### Adding GitHub Organizations
Add new sections following the existing pattern:

```toml
[github_neworg_issues]
service = "github"
login = "edmundmiller"
token = "@oracle:eval:op read \"op://Private/GitHub Personal Access Token/token\""
username = "edmundmiller"
description_template = "{{githubtitle}}"
project_template = "{{githubrepo|replace('/', '.')}}"
query = "is:issue assignee:edmundmiller is:open org:neworg"
include_user_issues = false
include_user_repos = false
add_tags = ["github", "bw", "assigned"]
default_priority = "L"
workspace_template = "neworg"
```

## Troubleshooting

### Authentication Issues
```bash
# Test 1Password access
op read "op://Work/Bugwarrior Jira/username"
op read "op://Private/GitHub Personal Access Token/token"

# Check 1Password session
op account list
```

### Sync Issues
```bash
# Verbose dry run
bugwarrior-pull --dry-run --debug

# Check specific service output
bugwarrior-pull --dry-run 2>&1 | grep -A5 "seqera_jira"
```

### Taskwarrior UDA Issues
```bash
# Reconfigure UDAs
bugwarrior-uda

# Check current UDAs
task config | grep uda
```

## Security Notes

- Credentials are stored securely in 1Password
- API tokens are retrieved at runtime via `@oracle:eval`, never stored in plaintext
- Jira token is in Work vault, GitHub/Linear tokens in Private vault

## Integration with Other Tools

### With Obsidian-Taskwarrior Sync
Bugwarrior tasks will automatically appear in your Obsidian vault when using the obsidian-taskwarrior-sync integration.

### With Timewarrior
Start tracking time on bugwarrior tasks:
```bash
task 123 start  # Starts timewarrior tracking via hook
```

## Dependencies

- [Bugwarrior](https://bugwarrior.readthedocs.io/) - Issue tracking sync
- [1Password CLI](https://developer.1password.com/docs/cli/) - Credential management
- [Taskwarrior](https://taskwarrior.org/) v3+ - Task management
- Python 3.8+ (via uv)
