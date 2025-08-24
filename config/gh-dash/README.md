# GitHub Dashboard Configuration

This directory contains the GitHub Dashboard (`gh-dash`) configuration that provides a powerful TUI for managing PRs and issues across multiple repositories and organizations.

## Overview

gh-dash is a GitHub CLI extension that displays a configurable dashboard of pull requests and issues. This configuration is optimized for managing work across multiple organizations including nf-core, seqeralabs, Applied-Genomics-UTD, and personal projects.

## Files

- `config.yml` - Main configuration file with sections, keybindings, and theme
- `README.md` - This documentation file

## Quick Start

```bash
# Launch the dashboard
gh dash

# Launch with specific config (if needed)
gh dash --config ~/.config/gh-dash/config.yml
```

## PR Sections

The dashboard is organized into focused sections for different types of work:

| Section | Purpose | Filters |
|---------|---------|---------|
| 📝 My Open PRs | Your active work | `author:@me` |
| 👁️ Needs My Review | PRs awaiting your review | `review-requested:@me` |
| 🚧 Draft PRs | Work in progress | `is:draft author:@me` |
| 🧬 nf-core PRs | nf-core ecosystem work | `org:nf-core involves:@me` |
| ⚡ Nextflow PRs | Core Nextflow work | `org:nextflow-io involves:@me` |
| 🎓 Applied Genomics PRs | Student/teaching work | `org:Applied-Genomics-UTD` |
| 🏢 Seqera PRs | Seqera platform work | `org:seqeralabs involves:@me` |
| 🤖 Dependabot PRs | Automated updates | `author:app/dependabot involves:@me` |

## Issue Sections

| Section | Purpose | Filters |
|---------|---------|---------|
| 🐛 My Issues | Issues you created | `author:@me` |
| ✅ Assigned to Me | Issues assigned to you | `assignee:@me` |
| 🧬 nf-core Issues | nf-core ecosystem issues | `org:nf-core involves:@me` |
| 🎓 Student Issues | Teaching-related issues | `org:Applied-Genomics-UTD involves:@me` |
| 🔥 Hot Issues | Popular issues you're involved in | `involves:@me sort:reactions-desc` |

## Keybindings

### Universal (work everywhere)
- `b` - Open repository in browser
- `y` - Copy current URL to clipboard

### PR Operations
- `o` - Open PR in browser
- `O` - Checkout PR locally
- `a` - Quick approve with "LGTM! ✅"
- `A` - Approve with custom comment
- `r` - Request changes
- `m` - Merge with squash
- `R` - Mark draft as ready for review
- `d` - View diff in neovim
- `c` - Add comment

### Issue Operations
- `o` - Open issue in browser
- `c` - Add comment
- `x` - Close issue
- `@` - Assign to yourself

## Navigation

- `j/k` or `↑/↓` - Move between items
- `h/l` or `←/→` - Switch between sections
- `tab` - Toggle preview pane
- `q` - Quit
- `?` - Show help

## Theme

The configuration uses **Catppuccin Mocha** colors to match your terminal theme:
- Primary text: `#cdd6f4`
- Secondary text: `#a6adc8`
- Selected background: `#45475a`
- Borders: `#6c7086`

## Configuration Details

### Auto-refresh
- PRs refresh every 60 seconds
- Branches refresh every 30 seconds
- Full dashboard refreshes every 5 minutes

### Display Settings
- Shows up to 25 PRs per section
- Shows up to 20 issues per section
- Preview pane opens by default at 55% width
- Author icons enabled for quick recognition
- Section counts displayed

### Integration
- Uses `delta` for diff viewing
- Configured for `pbcopy` (macOS clipboard)
- Opens browser with `open` command (macOS)

## Workflow Examples

### Morning Review Routine
1. Launch `gh dash`
2. Check "👁️ Needs My Review" section
3. Use `a` to quickly approve straightforward PRs
4. Use `O` to checkout complex PRs for local review
5. Use `d` to view diffs in neovim

### PR Management
1. Review "📝 My Open PRs" for status updates
2. Use `m` to merge approved PRs
3. Use `R` to mark drafts as ready
4. Monitor "🤖 Dependabot PRs" for updates

### Organization Work
1. Check org-specific sections (nf-core, Seqera, etc.)
2. Use `y` to copy URLs for sharing
3. Use `@` to assign issues to yourself
4. Use `c` to add comments and feedback

## Troubleshooting

### Config Not Loading
```bash
# Verify config location
echo $GH_DASH_CONFIG
ls -la ~/.config/gh-dash/

# Force specific config
gh dash --config ~/.config/gh-dash/config.yml
```

### Keybindings Not Working
- Ensure GitHub CLI is authenticated: `gh auth status`
- Check that commands work manually: `gh pr list`
- Verify repository access permissions

### Theme Issues
- Terminal must support 24-bit color
- Ensure terminal theme doesn't override colors
- Check `$TERM` environment variable

## Customization

The configuration is managed through nix-darwin. To modify:

1. Edit `/Users/emiller/.config/dotfiles/config/gh-dash/config.yml`
2. Run `hey rebuild` to update symlinks
3. Restart gh-dash to apply changes

### Adding New Sections
```yaml
prSections:
  - title: "🎯 New Section"
    filters: "is:open your-filters-here"
    type: null
```

### Custom Keybindings
```yaml
keybindings:
  prs:
    - key: "your-key"
      name: "action name"
      command: "your-command-here"
```

## Tips

1. **Use filters effectively**: Combine `org:`, `repo:`, and `involves:@me` for focused views
2. **Leverage sorting**: Use `sort:updated-desc` for recent activity, `sort:reactions-desc` for popular items  
3. **Quick actions**: Master `a`, `m`, and `O` for common operations
4. **Preview mode**: Keep preview open to quickly scan PR details
5. **Copy URLs**: Use `y` to easily share PRs in Slack/email

This configuration transforms GitHub management from a context-switching web workflow into an efficient terminal-based process.