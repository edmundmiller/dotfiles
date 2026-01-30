# GitHub CLI Configuration

This directory contains the GitHub CLI (`gh`) configuration files that are symlinked to `~/.config/gh/`.

## Files

- `config.yml` - Main configuration file with settings and aliases
- `hosts.yml` - Authentication tokens (not tracked in git)

## Aliases

Quick shortcuts for common GitHub operations:

| Alias             | Command                                   | Description                         |
| ----------------- | ----------------------------------------- | ----------------------------------- |
| `gh co <pr>`      | `pr checkout`                             | Checkout a PR branch locally        |
| `gh v <pr>`       | `pr view`                                 | View PR details in terminal         |
| `gh vw <pr>`      | `pr view -w`                              | Open PR in web browser              |
| `gh lr`           | `pr list --search "review-requested:@me"` | List PRs requesting your review     |
| `gh lpr`          | `pr list --assignee @me`                  | List PRs assigned to you            |
| `gh approve <pr>` | `pr review --approve`                     | Quick approve a PR                  |
| `gh draft`        | `pr create --draft`                       | Create a new draft PR               |
| `gh ready <pr>`   | `pr ready`                                | Mark a draft PR as ready for review |

## Shell Functions

Additional helper functions are defined in `config/git/aliases.zsh`:

### `ghprs`

Shows a quick overview of all your PR activity:

- PRs requesting your review
- Your assigned PRs
- Your recent PRs

### `ghmr <pr-number>`

Merge a PR with squash and cleanup:

- Squashes commits
- Deletes the branch
- Pulls latest changes

### `ghf <repo>`

Fork a repository:

- Clones it locally
- Sets up remote tracking

## Extensions

### gh-notify

Better notification management without the web interface.

```bash
# Basic usage
gh notify         # Show unread notifications
gh notify -p      # Only participating/mentioned
gh notify -r      # Mark all as read

# Filtering
gh notify -f "repo-name"    # Filter by repository
gh notify -e "dependabot"   # Exclude noise

# Interactive mode
gh notify -w      # Interactive with previews
```

**Interactive Mode Keys:**

- `Tab` - Toggle preview
- `Ctrl+T` - Mark as read
- `Ctrl+B` - Open in browser
- `Ctrl+A` - Mark all as read
- `Esc` - Quit

### gh-dash

Dashboard view for PRs and issues (already installed).

```bash
gh dash           # Open dashboard
```

## Workflow Examples

### Morning Routine

```bash
gh lr             # Check PRs requesting review
gh notify -p      # Check important notifications
ghprs             # Overview of all PR activity
```

### PR Review

```bash
gh co 123         # Checkout PR
gh v 123          # View details
gh approve 123    # Approve when ready
```

### End of Day

```bash
gh notify -r      # Clear all notifications
```

## Configuration

The configuration is managed through nix-darwin and will be symlinked on system rebuild:

```bash
hey rebuild       # Rebuild system with new config
```

Settings can be modified in `config.yml` and will take effect immediately.
