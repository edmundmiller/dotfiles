# Workmux Module

Tmux-native git worktree manager for parallel AI agent workflows.

## Installation

Enable in your host configuration:

```nix
modules = {
  shell.workmux.enable = true;
  shell.tmux.enable = true;  # Required dependency
};
```

Then rebuild: `hey rebuild`

## What This Module Provides

- **workmux binary** - Installed from github:raine/workmux flake
- **Global config** - Symlinked to `~/.config/workmux/config.yaml`
- **Shell aliases** - `wm`, `wml`, `wma`, `wmm`, `wmr`, `wmd`
- **Shell completions** - Automatically provided by the flake

## Files

| Source                       | Purpose                      |
| ---------------------------- | ---------------------------- |
| `config/workmux/config.yaml` | Global workmux configuration |
| `config/workmux/aliases.zsh` | Shell aliases                |

## Aliases

### Core Commands

| Alias | Command             | Description        |
| ----- | ------------------- | ------------------ |
| `wm`  | `workmux`           | Base command       |
| `wml` | `workmux list`      | List worktrees     |
| `wma` | `workmux add`       | Create worktree    |
| `wmm` | `workmux merge`     | Merge worktree     |
| `wmr` | `workmux remove`    | Remove worktree    |
| `wmd` | `workmux dashboard` | Open TUI dashboard |

### Quick Patterns

| Alias    | Command             | Description            |
| -------- | ------------------- | ---------------------- |
| `wma-b`  | `workmux add -b`    | Background (no switch) |
| `wma-A`  | `workmux add -A`    | Auto-name from prompt  |
| `wma-bA` | `workmux add -b -A` | Background + auto-name |

## Configuration

Global config at `~/.config/workmux/config.yaml`:

```yaml
main_branch: main
agent: opencode
merge_strategy: rebase
status_icons:
  working: "●"
  waiting: "■"
  done: "□"
nerdfont: true

auto_name:
  model: claude-haiku-4.5
  system_prompt: |
    Generate concise kebab-case branch name...
```

**Note:** Status icons match `opencode-tmux-namer` for consistency. The plugin handles status display natively via OpenCode events.

### Project Config

Create `.workmux.yaml` in project root:

```yaml
# Bare repo layout
worktree_dir: "{{ branch | sanitize }}/"

# Inherit from global
main_branch: "<global>"
agent: "<global>"

# Direnv integration
post_create:
  - direnv allow

# File handling
files:
  symlink: [.envrc]
  copy: [.env]
```

## Workflow

### Create Worktree with Agent

```bash
# Manual branch name
wma feature-name -a claude

# Auto-generated name from prompt
wma-A  # Opens editor, generates branch from content

# Background (don't switch)
wma-b fix-bug -a claude
```

### Monitor Agents

```bash
# TUI dashboard
wmd

# List worktrees (shows status icons in tmux)
wml
```

### Merge and Cleanup

```bash
wmm  # Rebase, merge, remove worktree
```

## Tmux Integration

Workmux creates:

- **One session per project** (named after repo)
- **One window per worktree** (named after branch)
- Status icons in window names show agent state

Use sesh (C-c t) to switch between project sessions.

## Troubleshooting

### workmux command not found

Rebuild and restart shell:

```bash
hey rebuild
exec zsh
```

### Tmux assertion fails

Ensure tmux module is enabled in your host config.

### Agent not starting

Check that `claude` (or configured agent) is available in PATH.

## See Also

- [Workmux Documentation](https://workmux.raine.dev)
- [Git Worktree Caveats](https://workmux.raine.dev/guide/git-worktree-caveats)
- `packages/opencode-tmux-namer` - Native status tracking (handles tmux naming)
