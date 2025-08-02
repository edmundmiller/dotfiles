# Bugwarrior Integration

This dotfiles configuration includes bugwarrior setup for syncing issues from Jira and GitHub into Taskwarrior, with secure credential management via 1Password.

## Overview

Bugwarrior automatically pulls issues from:
- ✅ **Seqera Jira** - Assigned issues and work items
- ✅ **Seqera GitHub** - Issues from organization repositories  
- ✅ **Personal GitHub** - Issues from your personal repositories
- ✅ **1Password Integration** - Secure credential storage
- ✅ **Automated Sync** - Optional scheduled updates

## Quick Setup

### 1. Install & Configure
```bash
# Install bugwarrior (already done)
uv tool install bugwarrior

# Set up 1Password credentials
setup-bugwarrior-credentials

# Configure taskwarrior UDAs and test config
setup-bugwarrior
```

### 2. Test the Setup
```bash
# Dry run (safe test)
bugwarrior-pull --dry-run

# First real sync
bugwarrior-pull
```

### 3. Optional: Automated Sync
```bash
# Set up automatic syncing every 30 minutes
setup-bugwarrior-sync
```

## Configuration Details

### Services Configured

1. **Seqera Jira** (`seqera_jira`)
   - URL: `https://seqera.atlassian.net`
   - Imports assigned, unresolved issues
   - Tags: `jira`, `seqera`
   - Imports labels and sprints as tags

2. **Seqera GitHub** (`seqera_github`)
   - Organization: `seqeralabs`
   - Repos: `platform`, `tower-cli`, `wave`, `fusion`, `nf-tower`
   - Imports issues where you're involved
   - Tags: `github`, `seqera`

3. **Personal GitHub** (`personal_github`)
   - Your personal repositories
   - All issues where you're involved
   - Tags: `github`, `personal`

### 1Password Items Required

The setup creates these 1Password items:

- **"Seqera Jira"** - Jira username and API token
- **"GitHub Token"** - GitHub username and personal access token (for Seqera repos)
- **"GitHub Personal Token"** - Token for personal repositories

### Taskwarrior Integration

Bugwarrior creates User Defined Attributes (UDAs) in Taskwarrior:

#### Jira Fields
- `jiracreatedts` - Issue creation timestamp
- `jiradescription` - Issue description  
- `jirastatus` - Current status
- `jiraurl` - Direct link to issue

#### GitHub Fields
- `githubrepo` - Repository name
- `githubtitle` - Issue title
- `githuburl` - Direct link to issue
- `githubtype` - Issue or Pull Request

## Usage

### Quick Commands (Fish Aliases)
```bash
# Sync commands
bw              # Full sync (bugwarrior-pull)
bw-dry          # Dry run test
bw-sync         # Safe sync with logging

# View tasks
bw-tasks        # All bugwarrior tasks
bw-jira         # Jira issues only
bw-github       # GitHub issues only  
bw-seqera       # Seqera-related tasks

# Logs and debugging
bw-log          # Follow sync log
bw-errors       # Follow error log

# Setup commands
bw-setup        # Configure bugwarrior
bw-creds        # Set up 1Password items
bw-auto         # Set up automation
```

### Direct Commands
```bash
# Manual sync
bugwarrior-pull

# Test configuration
bugwarrior-pull --dry-run

# Safe sync with logging
bugwarrior-sync
```

### Taskwarrior Queries
```bash
# Show all imported issues
task project:bugwarrior list

# Show by service
task +jira list
task +github list

# Show by organization  
task +seqera list
task +personal list

# Show specific repo issues
task description.contains:"platform" list
```

## File Locations

### Configuration
- **Main config**: `~/.config/dotfiles/config/bugwarrior/bugwarriorrc`
- **Symlinked to**: `~/.config/bugwarrior/bugwarriorrc`
- **Fish aliases**: `~/.config/dotfiles/config/bugwarrior/aliases.fish`

### Scripts
- `bin/setup-bugwarrior-credentials` - 1Password setup
- `bin/setup-bugwarrior` - Main configuration
- `bin/setup-bugwarrior-sync` - Automation setup
- `~/.local/bin/bugwarrior-sync` - Safe sync wrapper

### Logs
- `~/.local/share/bugwarrior/sync.log` - Sync activity
- `~/.local/share/bugwarrior/launchd.log` - Automation logs  
- `~/.local/share/bugwarrior/launchd-error.log` - Error logs

## Customization

### Adding Repositories
Edit `~/.config/dotfiles/config/bugwarrior/bugwarriorrc`:

```toml
[seqera_github]
# Add repos to this list
include_repos = platform, tower-cli, wave, fusion, nf-tower, new-repo
```

### Custom Jira Queries
```toml
[seqera_jira]
# Example: Include issues in specific projects
query = project in (PLATFORM, WAVE) AND assignee = currentUser() AND resolution = Unresolved
```

### Additional GitHub Organizations
Add new sections:
```toml
[another_org]
service = github
login = @oracle:eval:op item get "GitHub Token" --fields label=username
token = @oracle:eval:op item get "GitHub Token" --fields label=token
username = another-org
add_tags = github, another-org
```

## Troubleshooting

### Authentication Issues
```bash
# Test 1Password access
op item get "Seqera Jira" --fields label=username
op item get "GitHub Token" --fields label=token

# Check 1Password session
op account list
```

### Sync Issues
```bash
# Verbose dry run
bugwarrior-pull --dry-run --debug

# Check logs
tail -f ~/.local/share/bugwarrior/sync.log

# Test individual services
bugwarrior-pull --dry-run --only-if-assigned
```

### Taskwarrior UDA Issues
```bash
# Reconfigure UDAs
bugwarrior-uda

# Check current UDAs
task config | grep uda
```

## Automation Management

### Enable/Disable Automation
```bash
# Disable
launchctl unload ~/Library/LaunchAgents/com.user.bugwarrior.plist

# Enable  
launchctl load ~/Library/LaunchAgents/com.user.bugwarrior.plist

# Check status
launchctl list | grep bugwarrior
```

### Change Sync Frequency
Edit `~/Library/LaunchAgents/com.user.bugwarrior.plist`:
```xml
<key>StartInterval</key>
<integer>3600</integer>  <!-- 1 hour instead of 30 minutes -->
```

Then reload:
```bash
launchctl unload ~/Library/LaunchAgents/com.user.bugwarrior.plist
launchctl load ~/Library/LaunchAgents/com.user.bugwarrior.plist
```

## Security Notes

- Credentials are stored securely in 1Password
- API tokens are retrieved at runtime, never stored in plaintext
- Sync logs are local only
- Consider using separate GitHub tokens for different access levels

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