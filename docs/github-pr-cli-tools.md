# GitHub PR CLI Tools Guide

A practical guide for terminal-based GitHub PR management in high-volume workflows, particularly relevant for AI-assisted development.

## The Problem

AI coding assistants have increased PR volume by 8.69% and reduced time-to-PR from 9.6 to 2.4 days. The median engineer now takes 13 hours to merge a pull request, with most time spent waiting on reviews. Terminal-focused developers managing 10+ PRs daily need efficient tooling.

## Primary Tools Comparison

### gh dash: The Dashboard Approach

**Best for**: PR queue management and cross-repository discovery

- **Stars**: 8,800+ GitHub stars
- **Strengths**:
  - Persistent, customizable PR dashboard across multiple repos/orgs
  - Rich metadata display (review status, CI/CD, collaborators, merge status)
  - Keyboard-driven workflow (d=diff, v=approve, m=merge, c=checkout)
  - Sidebar tabs (Overview, Checks, Files) with `[` and `]` navigation
  - Auto-refresh capability (configurable, typically 15-30 minutes)
  - Scalable to dozens of repositories

- **Configuration**: Uses GitHub filter syntax for custom sections
  - Example: `is:open review-requested:@me label:urgent`
  - Example: `is:open author:@me updated:>={{ nowModify "-1w" }}`

- **Limitations**:
  - GitHub-only (no GitLab/Bitbucket)
  - Requires YAML configuration and Nerd Fonts
  - No inline code annotation (pair with Octo.nvim or browser)

### Octo.nvim: The In-Editor Approach

**Best for**: Deep, interactive code review of specific PRs

- **Stars**: 2,900+ GitHub stars
- **Requirements**: Neovim ≥0.10.0, gh CLI, plenary.nvim, picker (Telescope/fzf-lua/Snacks)
- **Strengths**:
  - Interactive review mode (`Octo review start`) with dual-pane diff view
  - Navigate files with `]q`/`[q`, add comments with `<localleader>ca`
  - Edit PR descriptions/comments like normal buffers, `:w` to sync
  - LSP functionality on PR code (go-to-definition, find-references)
  - Telescope integration for fuzzy finding all GitHub operations

- **Limitations**:
  - No built-in queue management or PR prioritization
  - Cannot work offline (requires API access)
  - No commit-level review or file-level comments
  - Medium to high setup complexity (50-200+ lines of config)

### The Optimal Strategy: Use Both

Configure gh dash with a hotkey to open selected PRs in Neovim with Octo.nvim:
```
tmux new-window -c {{.RepoPath}} 'nvim -c ":silent Octo pr edit {{.PrNumber}}}"'
```

This combines gh dash's superior triage with Octo's detailed review interface.

## Alternative Tools

- **prr**: Editor-agnostic markup reviews using `@prr` directives
- **gh.nvim**: Commit-wise deep review with full LSP support
- **gitui**: Blazing fast local Git operations (20.6k stars)
- **git-branchless**: Stacked PR workflows and trunk-based development (3.5k stars)
- **Neogit**: Best-in-class Magit-style Git interface for Neovim (4.9k stars)

## Managing AI-Generated PR Volume

### Pre-Review Automation

**AI Review Tools** (reduce review time by 40-50%):
- **CodeRabbit**: $12-15/month, automated PR summaries and line-by-line AI review
- **Qodo Merge / PR-Agent**: Open-source + enterprise ($19/user/month), CLI-friendly
- **Graphite Agent**: RAG-based learning from past PRs
- **Fine**: $15/month, pre-review automation for entire team

### Four-Layer Review Strategy

1. **Layer 1** (0 human time): Automated pre-checks (linting, tests, security)
2. **Layer 2** (0 human time): AI review for bugs and code smells
3. **Layer 3** (focused human review): Business logic, architecture, API design
4. **Layer 4** (sampling): Spot checks of AI-approved PRs

### Stacked PRs: The Meta/Google Workflow

Break large features into chains of small, dependent PRs reviewable independently.

**Graphite CLI** (`gt` command):
- `gt branch create -m "Add feature"` - Create stacked branch
- `gt commit create` - Commit changes
- `gt stack submit` - Submit entire stack
- `gt stack restack` - Rebase entire chain after parent changes

**When to use**: Large features, database migrations, cross-team dependencies, API changes

Benefits: Review 200-line PRs in 20 minutes vs. 2 hours for 1,000-line monoliths

### Size-Based Review Guidelines

- **Small PRs** (<200 lines): Same-day reviews, 15-30 minutes
- **Medium PRs** (200-500 lines): 1-2 hours, may need multiple reviewers
- **Large PRs** (>500 lines): Should be rare—use stacking instead

Research shows review accuracy drops significantly beyond 200-400 lines.

### SLA-Based Prioritization

- **Critical/blocking**: <2 hours
- **High priority**: <4 hours
- **Normal**: <24 hours
- **Low priority** (docs, refactoring): <48 hours

## Tool Selection Recommendations

**Terminal purists managing 10+ PRs daily**:
- Install gh-dash immediately
- Invest 2-3 hours in YAML configuration
- Pair with Graphite for stacked PRs

**Neovim power users**:
- Use Octo.nvim (expect 2-4 weeks to reach full proficiency)
- Use gh-dash in separate terminal for queue management
- Start with minimal config, add customization gradually

**Teams adopting AI coding assistants**:
- Implement CodeRabbit or Qodo PR-Agent immediately
- Configure GitHub Actions for automated pre-checks
- Consider gitStream for workflow automation

**Stacked PR workflows**:
- Use Graphite (CLI + web dashboard + VS Code extension)
- Start with 2-3 pilot developers
- Expand team-wide if successful

**Quick wins without extensive setup**:
- Install GitHub CLI and create aliases
- Add Qodo PR-Agent open-source version (30-minute setup)
- Implement PR size guidelines (200-400 lines)

## GitHub CLI Foundation

Essential commands scriptable in any terminal workflow:
```bash
gh pr list
gh pr view 123 --comments
gh pr checkout 123
gh pr review 123 --approve
gh pr diff 123
```

Custom aliases:
```bash
gh alias set bugs 'issue list --label="bugs"'
```

## Integration Patterns

Typical tool combination (5-10 Git/GitHub tools):
- **lazygit/gitui**: Local Git operations
- **gh-dash**: PR discovery and queue management
- **Octo.nvim**: Deep reviews
- **diffview.nvim**: Merge conflicts
- **gitsigns.nvim**: Local changes
- **git-branchless**: Stacked workflows

Each tool excels at specific tasks with seamless hand-offs between them.

## Key Metrics to Track

- Time to first review
- Time to merge
- Number of review rounds (aim for 1-2)
- PR size distribution (aim for smaller)
- Review load per developer (aim for 3-5 PRs max simultaneously)
- Bug escape rate (production issues)

## Conclusion

The terminal-based PR management ecosystem offers specialized tools for every workflow. Teams combining gh dash for queue management, Octo.nvim for deep review, AI-powered tools like CodeRabbit for automation, and Graphite for stacked workflows report 40-50% faster review cycles without sacrificing code quality—critical as AI coding assistants continue increasing code generation velocity.
