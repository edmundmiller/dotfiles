# GitHub Dashboard Configuration

This directory contains the GitHub Dashboard (`gh-dash`) configuration with **Graphite-inspired features**, providing a powerful TUI for managing PRs and issues across multiple repositories with priority inbox organization and stacked PR support.

## Overview

gh-dash is a GitHub CLI extension that displays a configurable dashboard of pull requests and issues. This configuration is optimized for:

- **Graphite-style priority inbox** - Organized by review status and urgency
- **Stacked PR workflow** - Track dependent PRs and branch relationships
- **jj-spr integration** - Native support for jujutsu stacked PR workflows
- **Multi-org management** - Work across nf-core, Seqera, and Nextflow organizations

## Quick Start

```bash
# Launch the dashboard
gh dash

# Launch with specific config (if needed)
gh dash --config ~/.config/gh-dash/config.yml
```

## Priority Inbox Sections (Graphite-Inspired)

The dashboard implements a Graphite-style priority inbox that organizes PRs by urgency and status:

### Immediate Action Required

| Section                      | Purpose                                   | Filters                                     |
| ---------------------------- | ----------------------------------------- | ------------------------------------------- |
| 🚨 Needs My Review (Urgent)  | PRs awaiting review (updated in last 24h) | `review-requested:@me updated:>24h`         |
| 🔄 Changes Requested         | Your PRs requiring updates                | `author:@me review:changes_requested`       |
| ✅ Approved & Ready to Merge | PRs ready to ship                         | `author:@me review:approved status:success` |

### Stacked PR Tracking

gh-dash now includes dedicated sections for managing stacked PRs:

| Section                         | Purpose                       | Filters                              |
| ------------------------------- | ----------------------------- | ------------------------------------ |
| 📚 My Stacks (Base Branch main) | Root PRs in your stacks       | `author:@me base:main`               |
| 🔗 Dependent PRs (Stacked)      | PRs based on feature branches | `author:@me -base:main -base:master` |
| 🌲 Stack Activity               | Recently updated stack PRs    | `author:@me updated:>48h`            |

**Stacked PR Workflow:**

1. View your base PRs in "📚 My Stacks"
2. Track dependent PRs in "🔗 Dependent PRs"
3. Use `S` key to view stack status
4. Use `ctrl+s` to see branch relationships
5. Use `J` to land PRs with jj-spr

### Active Work

| Section                   | Purpose                                 | Filters                              |
| ------------------------- | --------------------------------------- | ------------------------------------ |
| 📝 My Open PRs (Active)   | Your active work (updated in last week) | `author:@me updated:>1w`             |
| 🚧 My Drafts              | Work in progress                        | `is:draft author:@me`                |
| ⏳ My PRs Awaiting Review | Waiting for reviewers                   | `author:@me review:none draft:false` |
| 💤 Stale PRs              | PRs needing attention (>2 weeks old)    | `author:@me updated:<2w`             |

### Team Coordination

| Section               | Purpose                      | Filters                    |
| --------------------- | ---------------------------- | -------------------------- |
| 👁️ Awaiting My Review | All PRs you need to review   | `review-requested:@me`     |
| 💬 Mentioned Me       | PRs where you were mentioned | `mentions:@me -author:@me` |
| 👥 Team Discussions   | High engagement PRs          | `involves:@me comments:>3` |

### Organization-Specific

| Section           | Purpose                | Filters                              |
| ----------------- | ---------------------- | ------------------------------------ |
| 🧬 nf-core PRs    | nf-core ecosystem work | `org:nf-core involves:@me`           |
| ⚡ Nextflow PRs   | Core Nextflow work     | `org:nextflow-io involves:@me`       |
| 🏢 Seqera PRs     | Seqera platform work   | `org:seqeralabs involves:@me`        |
| 🤖 Dependabot PRs | Automated updates      | `author:app/dependabot involves:@me` |

## Issue Sections

| Section           | Purpose                           | Filters                            |
| ----------------- | --------------------------------- | ---------------------------------- |
| 🐛 My Issues      | Issues you created                | `author:@me`                       |
| ✅ Assigned to Me | Issues assigned to you            | `assignee:@me`                     |
| 🧬 nf-core Issues | nf-core ecosystem issues          | `org:nf-core involves:@me`         |
| 🏢 Seqera Issues  | Seqera platform issues            | `org:seqeralabs involves:@me`      |
| 🔥 Hot Issues     | Popular issues you're involved in | `involves:@me sort:reactions-desc` |

## Using the `/` Search Feature

gh-dash has a powerful built-in search feature that lets you dynamically filter any section using GitHub's query syntax.

### How It Works

1. **Navigate to any section** using `h/l` or arrow keys
2. **Press `/`** to activate search mode
3. **Type your search query** using GitHub search syntax
4. **Press Enter** to apply the filter
5. **Navigate away or press `r`** to refresh and clear the filter

### Quick Search Patterns for Your Work

**Filter by Seqera Organizations:**

```
org:seqeralabs OR org:seqera-services OR org:nextflow-io
```

**Filter by nf-core:**

```
org:nf-core
```

**Combine Multiple Orgs:**

```
(org:seqeralabs OR org:nf-core) involves:@me
```

**Add Time Filters:**

```
org:seqeralabs updated:>2024-01-01
```

**Filter by Labels:**

```
org:nf-core label:bug status:failure
```

### Pro Tips

- **Filters stack with section filters**: If you're in "Needs My Review" and search `org:nf-core`, you'll see only nf-core PRs that need your review
- **Use parentheses for OR logic**: `(org:foo OR org:bar) label:urgent`
- **Negate with minus**: `-label:wontfix` excludes items with that label
- **Combine anything**: `org:seqeralabs author:@me -is:draft updated:>2024-10-01`

### Common Workflows

**Focus on Seqera Work:**

1. Go to "Awaiting My Review" section
2. Press `/`
3. Type: `org:seqeralabs OR org:seqera-services OR org:nextflow-io`
4. Now you only see Seqera-related PRs needing review

**Check nf-core Community Work:**

1. Go to any section (like "Mentioned Me")
2. Press `/`
3. Type: `org:nf-core`
4. View only nf-core items in that category

**Find Stale PRs for Specific Org:**

1. Go to "My Open PRs (Active)"
2. Press `/`
3. Type: `org:nf-core updated:<2024-10-01`
4. See old nf-core PRs needing attention

## Keybindings

### Universal (work everywhere)

- `b` - Open repository in browser
- `y` - Copy current URL to clipboard
- `/` - **Search/filter current section** (GitHub query syntax)
- `r` - Refresh section (clears search filter)
- `q` - Quit
- `?` - Show help

### PR Operations

#### Standard Actions

- `o` - Open PR in browser
- `O` - Checkout PR locally (requires repo path mapping)
- `a` - Quick approve with "LGTM! ✅"
- `A` - Approve with custom comment
- `r` - Request changes
- `m` - Merge with squash
- `R` - Mark draft as ready for review
- `d` - View diff with delta
- `c` - Add comment

#### jj-spr Integration (Stacked Workflow)

- `J` - **Land PR with jj-spr** - Merge PR using jj-spr land command
- `ctrl+j` - **Sync jj-spr stack** - Update entire stack
- `S` - **Show stack status** - Display current stack state
- `ctrl+s` - **View PR stack info** - Show branch relationships

### Issue Operations

- `o` - Open issue in browser
- `c` - Add comment
- `x` - Close issue
- `X` - Reopen issue
- `@` - Assign to yourself

### Navigation

- `j/k` or `↑/↓` - Move between items
- `h/l` or `←/→` - Switch between sections
- `tab` - Toggle preview pane
- `ctrl+d/u` - Scroll preview up/down

## Workflows

### Graphite-Style Morning Review Routine

1. **Launch dashboard**: `gh dash`
2. **Check urgent reviews**: Navigate to "🚨 Needs My Review (Urgent)"
3. **Quick approvals**: Use `a` for straightforward PRs
4. **Deep review**: Use `O` to checkout complex PRs locally
5. **View diffs**: Use `d` to examine changes with delta
6. **Request changes**: Use `r` when needed

### Stacked PR Management with jj-spr

1. **Create your stack locally**:

   ```bash
   jj-spr create
   ```

2. **Monitor stack in dashboard**:

   - Check "📚 My Stacks" for base PRs
   - Check "🔗 Dependent PRs" for stacked PRs
   - Use `S` to see stack status

3. **Review and land**:

   - Navigate to PR in dashboard
   - Press `S` to verify stack status
   - Press `J` to land PR with jj-spr
   - Press `ctrl+j` to sync remaining stack

4. **Track dependencies**:
   - Use `ctrl+s` to view branch relationships
   - Monitor "🌲 Stack Activity" for recent changes

### Priority Management

1. **Start with urgent items**: "🚨 Needs My Review (Urgent)"
2. **Address feedback**: "🔄 Changes Requested"
3. **Ship ready work**: "✅ Approved & Ready to Merge" → press `m`
4. **Clean up stale work**: "💤 Stale PRs"
5. **Monitor team**: "👥 Team Discussions"

### Organization-Specific Work

1. Navigate to org-specific section (🧬, ⚡, 🏢)
2. Use `/` to filter by specific orgs: `org:seqeralabs OR org:seqera-services`
3. Use `y` to copy URLs for sharing
4. Use `@` to assign issues to yourself
5. Use `c` to add comments and feedback

## Configuration Details

### Auto-Refresh

- Refreshes every 30 minutes (gh-dash default)
- Balances freshness with API rate limits
- Sections show real-time counts

### Display Settings

- Shows up to 25 PRs per section
- Shows up to 20 issues per section
- Preview pane opens by default at 55% width
- Author icons enabled for quick recognition
- Smart column visibility by section

### Repository Path Mapping

Configured for quick local checkout:

```yaml
repoPaths:
  nf-core/*: ~/src/nf-core/*
  seqeralabs/*: ~/src/seqera/*
  seqera-services/*: ~/src/seqera/*
  nextflow-io/*: ~/src/nextflow/*
  :owner/:repo: ~/src/:owner/:repo # Fallback pattern
```

Press `O` on any PR to checkout locally using these paths.

### Integration

- **Diff viewer**: Uses `delta` for beautiful diffs
- **Clipboard**: Configured for `pbcopy` (macOS)
- **Browser**: Opens with `open` command (macOS)
- **jj-spr**: Native integration for stacked workflows

## Theme

Uses **Catppuccin Mocha** colors to match your terminal theme:

- Primary text: `#cdd6f4`
- Secondary text: `#a6adc8`
- Selected background: `#45475a`
- Borders: `#6c7086`
- Success: `#a6e3a1`
- Warning: `#f9e2af`

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

### jj-spr Commands Failing

- Ensure jj-spr is installed: `which jj-spr`
- Check you're in a jj repository: `jj status`
- Verify repository path mapping in config

### Repository Checkout Failing

- Verify repository exists locally at mapped path
- Check path patterns in `repoPaths` section
- Ensure repository is cloned: `ls ~/src/<org>/<repo>`

### Theme Issues

- Terminal must support 24-bit color
- Ensure terminal theme doesn't override colors
- Check `$TERM` environment variable

## Comparison to Graphite

This configuration replicates many of Graphite's key features:

| Feature             | Graphite    | gh-dash       | Implementation                |
| ------------------- | ----------- | ------------- | ----------------------------- |
| **Priority Inbox**  | ✅ Native   | ✅ Yes        | Dedicated sections by status  |
| **Stacked PRs**     | ✅ Native   | ✅ Via jj-spr | Sections + jj-spr integration |
| **Quick Actions**   | ✅ Yes      | ✅ Yes        | Rich keybindings              |
| **Multi-repo**      | ✅ Yes      | ✅ Yes        | Organization filters          |
| **Custom Sections** | ✅ Yes      | ✅ Yes        | GitHub search syntax          |
| **Local Checkout**  | ✅ Yes      | ✅ Yes        | Path mapping + `O` key        |
| **Team Sharing**    | ✅ Built-in | ✅ Via git    | Share config files            |
| **AI Review**       | ✅ Premium  | ❌ No         | Use external tools            |
| **Analytics**       | ✅ Yes      | ❌ No         | Use GitHub Insights           |

**Advantages over Graphite:**

- ✅ Fully terminal-native (no context switching)
- ✅ No external service dependency (privacy)
- ✅ More powerful filtering (GitHub search syntax)
- ✅ Completely customizable keybindings
- ✅ Free and open-source
- ✅ Integrates with existing jj-spr workflow

## Customization

The configuration is managed through nix-darwin. To modify:

1. Edit `/Users/edmundmiller/.config/dotfiles/config/gh-dash/config.yml`
2. Run `hey rebuild` to update symlinks
3. Restart gh-dash to apply changes

### Adding New Sections

```yaml
prSections:
  - title: "🎯 New Section"
    filters: "is:open your-filters-here"
    limit: 20
    layout:
      author:
        width: 15
```

### Custom Keybindings

```yaml
keybindings:
  prs:
    - key: "your-key"
      name: "action name"
      command: "gh command {{.PrNumber}} {{.RepoName}}"
```

### Advanced Filtering

Use GitHub's full search syntax:

- Time filters: `updated:>={{ nowModify "-3d" }}`
- Logical operators: `-author:@me` (negation)
- Combined filters: `org:nf-core label:bug status:failure`
- Sort options: `sort:reactions-desc`, `sort:comments-desc`

## Tips

1. **Master the priority inbox**: Start each day with "🚨 Needs My Review"
2. **Use `/` search liberally**: Quickly filter any section by org, label, or date
3. **Leverage stacked sections**: Use "📚 My Stacks" to track complex work
4. **Use quick actions**: `a`, `m`, and `O` are your friends
5. **Copy URLs freely**: `y` makes sharing easy in Slack/email
6. **Preview mode**: Keep preview open to scan PR details quickly
7. **jj-spr integration**: Use `J` and `ctrl+j` for stack management
8. **Watch for staleness**: Check "💤 Stale PRs" weekly
9. **Org-specific focus**: Use search patterns like `org:seqeralabs OR org:seqera-services OR org:nextflow-io`
10. **Combine filters**: Stack section filters with your searches (e.g., "Needs Review" + `org:nf-core`)

## Resources

- [gh-dash Documentation](https://github.com/dlvhdr/gh-dash)
- [GitHub Search Syntax](https://docs.github.com/en/search-github/searching-on-github/searching-issues-and-pull-requests)
- [jj-spr Documentation](https://github.com/mmhat/jj-spr)
- [Graphite Comparison](https://graphite.dev/features)

This configuration transforms GitHub management from a context-switching web workflow into an efficient, Graphite-inspired terminal-based process with native support for stacked PRs and jj-spr integration.
