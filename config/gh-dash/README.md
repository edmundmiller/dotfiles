# GitHub Dashboard Configuration

This directory contains the GitHub Dashboard (`gh-dash`) configuration that provides a powerful TUI for managing PRs and issues across multiple repositories and organizations.

## Overview

gh-dash is a GitHub CLI extension that displays a configurable dashboard of pull requests and issues. This configuration is optimized for managing work across multiple organizations including nf-core, seqeralabs, Applied-Genomics-UTD, and personal projects.

**Configuration Philosophy**: This setup follows best practices from "CLI-Based GitHub PR Review Tools: A Practical Guide" for high-volume PR workflows, combining gh-dash's superior triage capabilities with Neovim's deep review interface. The optimal workflow: discover and prioritize in gh-dash, then dive deep in the editor.

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

The dashboard is organized into focused sections for different types of work, following SLA-based prioritization (urgent <2h, high priority <4h, normal <24h):

| Section                     | Purpose                                    | Filters                              | Priority  |
| --------------------------- | ------------------------------------------ | ------------------------------------ | --------- |
| 🚨 Urgent - Needs My Review | Critical PRs requiring immediate attention | `review-requested:@me label:urgent`  | <2 hours  |
| 📝 My Open PRs              | Your active work                           | `author:@me`                         | Monitor   |
| 👁️ Needs My Review          | PRs awaiting your review                   | `review-requested:@me`               | <4 hours  |
| 🔄 Recently Updated         | PRs with activity in the last week         | `involves:@me updated:>=-1w`         | Review    |
| 🚧 Draft PRs                | Work in progress                           | `is:draft author:@me`                | Monitor   |
| 🧬 nf-core PRs              | nf-core ecosystem work                     | `org:nf-core involves:@me`           | <24 hours |
| ⚡ Nextflow PRs             | Core Nextflow work                         | `org:nextflow-io involves:@me`       | <24 hours |
| 🎓 Applied Genomics PRs     | Student/teaching work                      | `org:Applied-Genomics-UTD`           | <24 hours |
| 🏢 Seqera PRs               | Seqera platform work                       | `org:seqeralabs involves:@me`        | <24 hours |
| 🤖 Dependabot PRs           | Automated updates                          | `author:app/dependabot involves:@me` | <48 hours |

## Issue Sections

| Section           | Purpose                           | Filters                                 |
| ----------------- | --------------------------------- | --------------------------------------- |
| 🐛 My Issues      | Issues you created                | `author:@me`                            |
| ✅ Assigned to Me | Issues assigned to you            | `assignee:@me`                          |
| 🧬 nf-core Issues | nf-core ecosystem issues          | `org:nf-core involves:@me`              |
| 🎓 Student Issues | Teaching-related issues           | `org:Applied-Genomics-UTD involves:@me` |
| 🔥 Hot Issues     | Popular issues you're involved in | `involves:@me sort:reactions-desc`      |

## Keybindings

### Universal (work everywhere)

- `b` - Open repository in browser
- `y` - Copy current URL to clipboard

### PR Operations

- `o` - Open PR in browser
- `O` - Checkout PR locally
- `C` - **Review in Neovim** (opens gh.nvim in tmux window - optimal workflow!)
- `a` - Quick approve with "LGTM! ✅"
- `A` - Approve with custom comment
- `r` - Request changes
- `m` - Merge with squash
- `M` - Merge with rebase (for small PRs)
- `R` - Mark draft as ready for review
- `d` - View diff in neovim
- `D` - View diff with delta pager
- `s` - View PR checks/CI status
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

### Optimal Workflow: gh-dash + Neovim (Recommended)

This setup implements the **optimal strategy from the CLI PR tools guide**: use gh-dash for queue management and discovery, then dive deep in Neovim for detailed review.

1. Launch `gh dash`
2. Navigate to "🚨 Urgent" or "👁️ Needs My Review" section
3. Press `C` on a PR to open it in Neovim with gh.nvim in a new tmux window
4. Review the PR in the editor with full LSP support and context
5. Return to gh-dash, press `a` to approve or `r` to request changes
6. Manage 3-5 PRs in parallel using tmux windows

**Benefits**:

- Combines gh-dash's superior triage with Neovim's deep review interface
- tmux integration enables parallel PR reviews without context switching
- Full LSP functionality (go-to-definition, find-references) on PR code
- No browser required for entire workflow

### Morning Review Routine

1. Launch `gh dash`
2. Check "🚨 Urgent" section first (SLA: <2 hours)
3. Check "👁️ Needs My Review" section (SLA: <4 hours)
4. Use `a` to quickly approve straightforward PRs (<200 lines)
5. Use `C` to open complex PRs in Neovim for deep review
6. Use `d` to quickly view diffs without full checkout

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
3. **Quick actions**: Master `a`, `m`, `C`, and `O` for common operations
4. **Preview mode**: Keep preview open to quickly scan PR details
5. **Copy URLs**: Use `y` to easily share PRs in Slack/email
6. **tmux workflow**: Use `C` keybinding to review 3-5 PRs in parallel tmux windows
7. **SLA awareness**: Prioritize based on urgency (urgent <2h, high <4h, normal <24h)

## Best Practices from the Guide

### PR Size Guidelines

- **Small PRs** (<200 lines): Same-day reviews, 15-30 minutes - use `a` for quick approval
- **Medium PRs** (200-500 lines): 1-2 hours - use `C` to review in Neovim with full context
- **Large PRs** (>500 lines): Should be rare - request splitting into stacked PRs

### Review Workflow

1. **Triage in gh-dash**: Use dashboard to prioritize and categorize PRs
2. **Deep review in Neovim**: Press `C` for complex PRs requiring code context
3. **Quick actions for simple PRs**: Use `a` for obvious approvals
4. **Check CI status**: Press `s` before reviewing to ensure tests pass
5. **Parallel reviews**: Manage multiple PRs simultaneously in tmux windows

### Managing High Volume

- Track metrics: Aim for 1-2 review rounds per PR
- Review load: 3-5 PRs max in review simultaneously
- Use "🔄 Recently Updated" section to catch PRs needing re-review
- Leverage the "🚨 Urgent" section for critical items

This configuration transforms GitHub management from a context-switching web workflow into an efficient terminal-based process optimized for high-volume PR workflows.
