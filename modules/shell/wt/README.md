# Worktrunk (wt) Module

Worktrunk shell integration for nix-darwin. Manages git worktrees for parallel AI agent workflows.

## Installation

Enable in host config:

```nix
modules.shell.wt.enable = true;
```

Requires homebrew tap (installed separately):

```bash
brew tap max-sixty/worktrunk
brew install wt
```

## What This Module Provides

- **Config symlink:** `~/.config/worktrunk/config.toml` -> nix store
- **Shell integration:** `eval "$(wt config shell init zsh)"` for directory changing
- **Aliases:** Shortcuts for common operations

## Files

| Source                  | Purpose                                                             |
| ----------------------- | ------------------------------------------------------------------- |
| `config/wt/config.toml` | User configuration (worktree paths, merge defaults, LLM commit gen) |
| `config/wt/env.zsh`     | Shell integration (enables `wt switch` to change dirs)              |
| `config/wt/aliases.zsh` | Command shortcuts                                                   |

## Aliases

### Core Commands

| Alias | Command     | Description     |
| ----- | ----------- | --------------- |
| `wtl` | `wt list`   | List worktrees  |
| `wts` | `wt switch` | Switch worktree |
| `wtm` | `wt merge`  | Merge + cleanup |
| `wtr` | `wt remove` | Remove worktree |

### Create + Launch Agent

| Alias     | Command                    | Description                       |
| --------- | -------------------------- | --------------------------------- |
| `wtcc`    | `wt switch -c -x claude`   | Create + launch Claude            |
| `wtco`    | `wt switch -c -x opencode` | Create + launch OpenCode          |
| `wtcc-bg` | (function)                 | Spawn Claude in background tmux   |
| `wtco-bg` | (function)                 | Spawn OpenCode in background tmux |

### Navigation

| Alias     | Command                 | Description              |
| --------- | ----------------------- | ------------------------ |
| `wtb`     | `wt switch -`           | Previous worktree        |
| `wtmain`  | `wt switch main`        | Jump to main             |
| `wtstack` | `wt switch -c --base=@` | Branch from current HEAD |
| `wtsel`   | `wt select`             | Interactive picker       |

### Status & Config

| Alias   | Command                 | Description         |
| ------- | ----------------------- | ------------------- |
| `wtst`  | `wt list --full`        | List with CI status |
| `wtj`   | `wt list --format=json` | JSON output         |
| `wtcfg` | `wt config show`        | Show config         |

## Config Options

Key settings in `config/wt/config.toml`:

```toml
# Worktree path pattern (sibling dirs by default)
worktree-path = "../{{ repo }}.{{ branch | sanitize }}"

# LLM commit message generation
[commit-generation]
command = "llm"
args = ["-m", "claude-haiku-4.5"]

# Merge behavior
[merge]
squash = true
rebase = true
remove = true  # Auto-remove worktree after merge
```

## Troubleshooting

### "Cannot change directory - shell integration not installed"

The shell integration requires `.zshenv` to source `extra.zshenv`. Verify:

```bash
grep "extra.zshenv" ~/.config/zsh/.zshenv
# Should show: [[ -f "$ZDOTDIR/extra.zshenv" ]] && source "$ZDOTDIR/extra.zshenv"
```

If missing, run `hey rebuild` to update the zsh config.

### wt command not found

```bash
brew tap max-sixty/worktrunk
brew install wt
exec zsh  # Reload shell
```

### Shell integration not loading

1. Check wt is in PATH: `which wt`
2. Verify env.zsh is sourced: `grep wt ~/.config/zsh/extra.zshenv`
3. Restart shell after `hey rebuild`
