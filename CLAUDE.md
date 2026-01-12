# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

This is a Nix-based dotfiles repository using Flakes for managing system configurations across macOS (nix-darwin) and NixOS. The primary hosts in use are:

- **Seqeratop**: Work macOS machine with development tools
- **MacTraitor-Pro**: Personal macOS machine
- **NUC**: NixOS home server (deployed remotely via `hey nuc`)

## Critical File Editing Rules

- We use jj for version control
- **ALWAYS write over the source file you're editing. Don't make "\_enhanced", "\_fixed", "\_updated", or "\_v2" versions.** We use version control - that's why everything is tracked. When in doubt, commit first if you want to preserve the original, but always overwrite the actual file.
- Don't make PRs in this repo. Just use the main bookmark.

## Essential Commands

**ALWAYS use the `hey` command** (located in `bin/hey`) as the primary interface to this system. The `hey` command is a modular JustScript that provides a clean, consistent interface to all nix-darwin operations.

```bash
# Primary hey commands (ALWAYS USE THESE):
hey rebuild      # Rebuild and switch to new configuration (alias: hey re)
hey test         # Build and activate but don't add to boot menu
hey upgrade      # Update flake inputs and rebuild
hey rollback     # Roll back to previous generation
hey gc           # Run garbage collection
hey check        # Run flake checks
hey show         # Show flake outputs
hey update       # Update flake inputs (alias: hey u)

# Remote deployment commands:
hey nuc          # Deploy to NUC server (will prompt for sudo password)
hey nuc-test     # Test NUC config without adding to boot menu
hey nuc-status   # Show NUC system status
hey nuc-ssh      # SSH into NUC
hey nuc-service <name>  # Check service status on NUC
hey nuc-rollback # Roll back NUC to previous generation

# Development commands:
hey search <term>    # Search for packages
hey shell <package>  # Start nix shell with package
hey repl            # Start nix repl with flake
```

**Fallback commands** (only use if `hey` is unavailable):

```bash
# Direct darwin-rebuild commands (use only as fallback):
sudo ./result/sw/bin/darwin-rebuild --flake .#MacTraitor-Pro switch  # Rebuild and switch
sudo ./result/sw/bin/darwin-rebuild --flake .#Seqeratop switch       # For Seqeratop host
darwin-rebuild --list-generations       # List available generations
sudo darwin-rebuild --rollback          # Roll back to previous generation
nix-collect-garbage -d                  # Garbage collection
```

## Architecture

The repository follows a modular architecture:

1. **flake.nix**: Entry point defining all inputs and outputs
2. **hosts/\*/default.nix**: Machine-specific configurations
3. **modules/**: Reusable configuration modules with a custom options system
4. **lib/**: Helper functions for module management and host configuration
5. **config/**: Application-specific dotfiles and configurations
6. **packages/**: Custom Nix packages and overlays

Configuration flow:

- `flake.nix` → `lib/hosts.nix` → `hosts/<hostname>/default.nix` → enabled modules

## Hey Command Architecture

The `hey` command is implemented as a modular JustScript system that provides the primary interface to nix-darwin operations:

**Main Script:**

- `bin/hey` - Executable JustScript with shebang `#!/usr/bin/env -S just --justfile`
- Uses `just` task runner for clean, maintainable command organization
- Imports modular components for different command categories

**Modular Structure (`bin/hey.d/`):**

- `common.just` - Shared variables, hostname mapping, and utility functions
- `rebuild.just` - System rebuild commands (`rebuild`, `test`, `rollback`)
- `flake.just` - Flake management (`update`, `upgrade`, `check`, `show`)
- `nix.just` - General nix utilities (`gc`, `repl`, `search`, `shell`)
- `remote.just` - Remote deployment commands for NixOS hosts (`nuc`, `nuc-test`, etc.)

**Key Features:**

- Automatic hostname mapping (Mac → MacTraitor-Pro)
- Darwin-rebuild fallback mechanism when not in PATH
- Platform detection (Darwin vs NixOS)
- Built-in help system with examples
- Command aliases (`re` for rebuild, `u` for update)
- Shows current flake host and platform in help output

## Key Patterns

### Adding/Modifying Host Configuration

Edit `hosts/<hostname>/default.nix` and enable/disable modules:

```nix
modules = {
  some-feature.enable = true;
  desktop.apps.chrome.enable = false;
};
```

### Module System

Modules are defined in `modules/` with options in `modules/options.nix`. They follow the pattern:

```nix
{ options, config, lib, pkgs, ... }:
with lib;
with lib.my;
let cfg = config.modules.<module-name>;
in {
  options.modules.<module-name> = { ... };
  config = mkIf cfg.enable { ... };
}
```

### Managing Secrets

- Credentials are stored in 1Password
- Use `op` CLI for accessing secrets
- Bugwarrior credentials: `bin/setup-bugwarrior-credentials`

## Common Development Tasks

### Testing Configuration Changes

1. Make changes to relevant files
2. **Ensure git is in sync with jj:** Nix flakes read from git, not jj. If you've made changes via jj, ensure the git `main` branch points to the correct commit:
   ```bash
   git checkout main          # Ensure git is on main branch
   jj log -r 'main | @'       # Verify jj main bookmark has your changes
   ```
   If git is in detached HEAD state or behind jj, the rebuild will use stale code.
3. Run `hey rebuild` (or `hey re` for short)
4. If issues occur: `hey rollback`

### Updating Dependencies

```bash
hey update                                     # Update all flake inputs
hey update <input>                            # Update specific input
hey upgrade                                   # Update inputs and rebuild system
```

### Adding New Packages

1. For temporary use: `hey shell <package>`
2. For permanent installation, add to host config or relevant module
3. Custom packages go in `packages/`

### Command Examples

```bash
hey help                    # Show all available commands with examples
hey search firefox         # Search for packages in nixpkgs
hey shell python3          # Start temporary shell with package
hey u nixpkgs              # Update specific input (alias for update)
```

## Remote NixOS Deployment

The repository includes a full remote deployment system for NixOS hosts, starting with the NUC server.

### Quick Start

```bash
# Deploy to NUC (interactive sudo password required)
hey nuc

# Check deployment status
hey nuc-status

# Roll back if needed
hey nuc-rollback
```

### How Remote Deployment Works

1. **Push changes**: Local commits pushed to GitHub (`jj git push`)
2. **SSH to target**: Connects to NUC via SSH (uses 1Password SSH agent)
3. **Update repository**: Pulls latest changes from GitHub on NUC
4. **Remote build**: Runs `nixos-rebuild` on NUC (native x86_64, fast)
5. **Interactive sudo**: Prompts for password (security best practice)

### Available Remote Commands

**Deployment:**
- `hey nuc` - Full deploy (recommended)
- `hey rebuild-nuc` - Alias for `hey nuc`
- `hey nuc-test` - Test without adding to boot menu

**Management:**
- `hey nuc-ssh` - SSH into NUC
- `hey nuc-status` - Show system status
- `hey nuc-service <name>` - Check service (e.g., `hey nuc-service docker`)
- `hey nuc-logs [unit]` - View system logs
- `hey nuc-rollback` - Roll back to previous generation
- `hey nuc-generations` - List all generations

**Advanced:**
- `hey nuc-local` - Build locally (slow cross-compile, testing only)

### NUC Configuration

**SSH Setup** (`modules/shell/ssh.nix`):
```nix
"nuc" = {
  hostname = "192.168.1.222";
  user = "emiller";
  forwardAgent = true;
};
```

**Host Config** (`hosts/nuc/default.nix`):
- Enable/disable modules like other hosts
- Services: docker, taskchampion, jellyfin, etc.
- See `hosts/nuc/DEPLOY.md` for detailed documentation

### Deployment Workflow Example

```bash
# 1. Make changes to NUC configuration
vim hosts/nuc/default.nix

# 2. Test locally for syntax errors
hey check

# 3. Deploy to NUC
hey nuc
# Enter sudo password when prompted

# 4. Verify service is running
hey nuc-service taskchampion-sync-server

# 5. If issues, roll back
hey nuc-rollback
```

### Why Remote Builds?

- **Fast**: Native x86_64 build vs. slow ARM→x86_64 cross-compile
- **Simple**: No cross-compilation complexity or emulation
- **Secure**: Interactive sudo prevents unauthorized deployments
- **Reliable**: Build on the actual target hardware

### Troubleshooting

**SSH connection fails:**
```bash
ssh nuc  # Test SSH host alias
ssh emiller@192.168.1.222  # Test direct connection
```

**Repository not found:**
The `hey nuc` command auto-clones on first run. If needed:
```bash
hey nuc-ssh
git clone https://github.com/edmundmiller/dotfiles.git ~/dotfiles-deploy
```

**Build failures:**
```bash
hey nuc-logs nixos-rebuild 100  # View build logs
hey nuc-rollback                # Restore previous working state
```

See `hosts/nuc/DEPLOY.md` for comprehensive deployment documentation.

## Claude Code Plugin Validation

This repository has comprehensive linting for Claude Code plugins using [claudelint](https://github.com/stbenjam/claudelint). Validation runs at multiple layers to catch issues early.

### Validation Layers

**1. Real-time (during editing):**

- The `claude-lint` plugin validates files as you save them
- Provides immediate feedback on plugin.json, commands, skills, and hooks
- Non-blocking: shows warnings but doesn't prevent operations
- See `config/claude/plugins/claude-lint/README.md` for details

**2. Pre-commit hook:**

- Validates staged plugin files before commit
- Located at `.git/hooks/pre-commit`
- Only checks changed files (strict for new changes only)
- Skip with `git commit --no-verify` if needed

**3. CI/CD (GitHub Actions):**

- Runs on every push/PR that touches plugin files
- Workflow: `.github/workflows/validate-plugins.yml`
- Validates all changed plugin directories
- Blocks merge if validation fails

**4. Nix flake checks:**

- Integrated into `hey check` and `nix flake check`
- Validates all plugins in the repository
- Part of the standard build verification process

### Plugin Directories

Current plugins:

- `config/claude/plugins/jj/` - Jujutsu version control integration
- `config/claude/plugins/json-to-toon/` - Token optimization format
- `config/claude/plugins/markdown-cleanup/` - Session file cleanup
- `config/claude/plugins/claude-lint/` - Plugin validation (this system)

### Validation Rules

Configuration: `.claudelint.toml`

Checks include:

- Plugin metadata and schema validation
- Required files and naming conventions
- Command and skill frontmatter
- Hook executability and shebang format
- Cross-reference validation
- Semantic versioning

### Running Validation Manually

```bash
# Validate a specific plugin
uvx claudelint config/claude/plugins/jj/

# Validate all plugins
for plugin in config/claude/plugins/*/; do
  uvx claudelint "$plugin"
done

# Run via flake checks (includes plugin validation)
hey check

# Or directly
nix flake check
```

### Troubleshooting Plugin Validation

**uvx not found:**

- Install uv: `curl -LsSf https://astral.sh/uv/install.sh | sh`
- Add to PATH: `export PATH="$HOME/.cargo/bin:$PATH"`

**Validation fails for existing plugins:**

- The system validates only changed files by default
- Fix issues or update `.claudelint.toml` configuration
- See validation output for specific errors

**Real-time validation not working:**

- Check that `claude-lint` plugin is enabled
- Verify hook is executable: `ls -l config/claude/plugins/claude-lint/hooks/`
- Check Claude Code plugin logs for errors

## Important Conventions

1. **Aliases** are defined in `config/<tool>/aliases.zsh`
2. **Environment variables** in `config/<tool>/env.zsh`
3. **Git configuration** uses includes for work/personal profiles
4. **Task management** uses Taskwarrior with Obsidian sync
5. **Shell** is zsh with extensive customization in `config/zsh/`

## Debugging

### System Information

- Check current generation: `darwin-rebuild --list-generations` or `hey help` for current host
- View logs: `log show --last 10m | grep -i darwin`
- Flake outputs: `hey show`
- Current flake host and platform: `hey help` (shown at bottom)
- Verify hey availability: `which hey` or `echo $DOTFILES_BIN`

### Hey Command Issues

- **Hey not found after rebuild**: Start a new terminal session to pick up updated environment variables
- **Check hey path**: The `$DOTFILES_BIN` environment variable should point to the nix store path containing hey
- **Verify just is available**: `which just` (required for JustScript execution)
- **Debug mode**: Add `-v` flag to just commands for verbose output

### Development Tools

- Nix repl with flake: `hey repl`
- Package search: `hey search <term>`
- Temporary package shell: `hey shell <package>`
- Flake validation: `hey check`

## Troubleshooting

### Common Issues

**Antidote not found warnings:**

- Antidote is installed at system level via `environment.systemPackages`
- After rebuilds, restart terminal to pick up new environment
- Check installation: antidote should be available in `/run/current-system/sw/bin/`

**Hey command not in PATH:**

- After system rebuild, the `$DOTFILES_BIN` environment variable may need a new shell session
- The hey script is managed through nix and available via `$DOTFILES_BIN/hey`
- Fallback: Use `./bin/hey` from repository root

**Environment variable issues:**

- Restart terminal after `hey rebuild` to pick up new environment variables
- Check `echo $PATH` includes `/run/current-system/sw/bin` and nix paths
- Verify `echo $DOTFILES_BIN` points to correct nix store path

## Homebrew Management

This repository uses `nix-homebrew` for proper homebrew integration:

- Homebrew runs with appropriate user privileges (not root)
- Configured with `enableRosetta` for Apple Silicon + Intel compatibility
- `autoMigrate` enabled to migrate existing homebrew installations
- Managed through the `homebrew` section in host configurations

## Jujutsu (JJ) Version Control

This repository uses jujutsu (jj) for version control. JJ is a Git-compatible VCS with a more intuitive model.

### Core JJ Workflows

**The Squash Workflow** - Describe → New → Implement → Squash:

1. `jj describe -m "what you're about to do"`
2. `jj new` (creates empty change)
3. Make your changes
4. `jj squash` (moves changes into parent)

**The Edit Workflow** - Edit any commit directly:

- `jj edit <change-id>` to edit any previous commit
- Changes automatically rebase
- No checkout dance needed

### Quick JJ Commands

- `/jj-status` - Smart overview of repository state
- `/jj-new` - Start new work properly
- `@squash` - Complete work via squash workflow (use the command shortcut)
- `@split` - Split mixed changes into focused commits
- `@undo` - Safety net for any operation

### Key JJ Principles

- **Everything is undoable**: `jj op log` shows all operations, `jj undo` reverses them
- **No staging area**: Changes are always in commits, just move them around
- **Automatic rebasing**: Edit any commit, descendants follow automatically
- **Conflicts don't block**: Conflicts are stored in commits, not working directory

When working with jj, think in terms of moving changes between commits rather than staging/unstaging. Use `jj status` and `jj log` frequently to understand state.

### JJ Editor Commands for Claude Code

When Claude Code needs to run JJ commands that normally open an editor, always use one of these approaches:

1. **Use -m flag for messages:**

   ```bash
   jj describe -m "commit message"
   jj squash -m "message"
   ```

2. **Use JJ_EDITOR environment variable for interactive commands:**

   ```bash
   JJ_EDITOR="echo 'commit message'" jj describe
   JJ_EDITOR="echo 'commit message'" jj split
   ```

3. **For heredoc messages:**
   ```bash
   jj describe -m "$(cat <<'EOF'
   Multi-line commit message
   with details
   EOF
   )"
   ```

**Never run:** `jj describe`, `jj split`, `jj squash` without specifying the message, as this will hang in an interactive editor that Claude Code cannot control.

### Beads Merge Integration

JJ is configured with automatic merge tool selection via `jj-smart-merge`:

- **`.beads/` files**: Automatically use `bd merge` (field-level 3-way merge)
- **All other files**: Use `diffconflicts` (nvim)

This means `jj resolve` automatically picks the right tool based on the conflicted file path.

**Manual tool override** (if needed):
```bash
jj resolve --tool=beads-merge    # Force beads merge for current conflict
jj resolve --tool=diffconflicts  # Force nvim for current conflict
```

**Why field-level merge matters for beads:**
Beads stores issues as JSON objects in `.beads/issues.jsonl`. Line-based merge would conflict when two people edit different fields of the same issue. Field-level merge combines changes intelligently:
- You change `status: "open"` → `"in_progress"`
- Coworker changes `priority: 2` → `3`
- Result: Both changes preserved, no conflict

See `config/jj/README.md` for detailed documentation.

## Worktrunk (Git Worktree Management)

**Purpose:** CLI for managing git worktrees, designed for running AI agents in parallel.

Worktrunk simplifies git worktree management with features like parallel agent tracking, LLM commit messages, CI status monitoring, and automated project hooks.

### Core Commands

```bash
wt switch <branch>              # Switch to worktree (creates if needed)
wt switch -c <branch>           # Create worktree + branch
wt switch -c -x claude <branch> # Create + launch Claude
wt switch -c -x opencode <branch> # Create + launch OpenCode
wt list                         # List all worktrees with status
wt list --full                  # Include CI status and diffstat
wt merge                        # Merge, squash, rebase, clean up
wt remove                       # Remove current worktree
wt select                       # Interactive worktree picker (fzf-like)
```

**Aliases available:**
- `wtl` → `wt list`
- `wts` → `wt switch`
- `wtm` → `wt merge`
- `wtr` → `wt remove`
- `wtcc` → `wt switch -c -x claude` (create + launch Claude)
- `wtco` → `wt switch -c -x opencode` (create + launch OpenCode)
- `wtcc-bg` → spawn Claude in background tmux session
- `wtco-bg` → spawn OpenCode in background tmux session
- `wtj` → `wt list --format=json` (JSON output for scripting)
- `wtstack` → `wt switch -c --base=@` (create branch from current HEAD)

### Key Features

**Parallel AI Agents:**
Run multiple Claude/OpenCode sessions on different branches simultaneously:
```bash
wt switch -c -x claude agent-1
wt switch -c -x opencode agent-2
wt list  # Shows agent activity: 🤖 (working) or 💬 (waiting)
```

**Activity Tracking:**
- 🤖 — AI agent is working
- 💬 — AI agent is waiting for input
- Integrates with Claude Code plugin for automatic status updates

**LLM Commit Messages:**
Auto-generate commit messages using Claude Haiku:
```bash
wt merge  # Generates commit message from diff, runs hooks, merges
```

**CI Status Monitoring:**
```bash
wt list --full
# Shows:
#   ✓ — CI passed
#   ● — CI running
#   ✗ — CI failed
#   ⚠ — Merge conflicts
```

**Project Hooks:**
Automate workflows with lifecycle hooks in `.config/wt.toml`:
- `post-create` — Setup after worktree creation
- `post-start` — Background processes (dev servers)
- `post-switch` — Terminal title updates
- `pre-commit` — Formatters, linters
- `pre-merge` — Tests, build verification
- `post-merge` — Notifications, deployment

### Configuration

**User config:** `~/.config/worktrunk/config.toml` (managed via nix)
```toml
# Worktree path template
worktree-path = "../{{ repo }}.{{ branch | sanitize }}"

# LLM commit messages
[commit-generation]
command = "llm"
args = ["-m", "claude-haiku-4.5"]

# Merge defaults
[merge]
squash = true
rebase = true
remove = true
```

**Project hooks:** `.config/wt.toml` (git-tracked)
```toml
[post-create]
info = "echo 'Worktree created: {{ branch }}'"

[pre-merge]
check = "hey check"  # Run flake checks before merge

[post-merge]
notify = "terminal-notifier -title 'Merged' -message '{{ branch }} → {{ target }}'"
```

### Worktree Path Patterns

**Default pattern:** `../<repo>.<branch-sanitized>`

Example for `~/.config/dotfiles` on branch `feature/auth`:
- Creates: `~/.config/dotfiles.feature-auth`

**Alternative patterns:**
```toml
# Inside repo (like beads)
worktree-path = ".worktrees/{{ branch | sanitize }}"

# Namespaced
worktree-path = "../worktrees/{{ repo }}/{{ branch | sanitize }}"

# Bare repo style
worktree-path = "../{{ branch | sanitize }}"
```

### Integration with Beads

Both `wt` and `bd worktree` manage worktrees but serve different purposes:

**Use `wt` for:**
- Parallel AI agent workflows
- General feature development with CI tracking
- Team workflows with standardized hooks

**Use `bd worktree` for:**
- Beads issue-specific workflows
- Issue-driven development

**Important:** When using beads in wt-managed worktrees, always use `--no-daemon`:
```bash
cd ~/code/myproject.feature-auth
bd --no-daemon list
bd --no-daemon work issue-123
```

See `docs/worktrunk-beads-integration.md` for detailed integration guide.

### Claude Code Plugin

**Installation (manual):**
```bash
claude plugin marketplace add max-sixty/worktrunk
claude plugin install worktrunk@worktrunk
```

**Features:**
- Configuration skill (documentation Claude can read)
- Activity tracking (🤖/💬 markers in `wt list`)
- Automatic status updates during sessions

**OpenCode:** Plugin compatibility TBD - may require separate installation.

### Troubleshooting

**wt command not found:**
```bash
hey rebuild  # Installs via homebrew
exec zsh     # Reload shell
```

**Can't change directory with `wt switch`:**
Shell integration not loaded. Should be automatic after `hey rebuild`, but can manually run:
```bash
eval "$(wt config shell init zsh)"
```

**Beads commands hang in worktree:**
Use `--no-daemon` flag:
```bash
bd --no-daemon list
```

**Want different worktree path pattern:**
Edit `~/.config/worktrunk/config.toml` and change `worktree-path` template.

### Common Workflows

**Parallel feature development:**
```bash
# Create multiple feature worktrees
wt switch -c feature/api
wt switch -c feature/ui
wt switch -c feature/auth

# Check all statuses
wt list --full

# Work in each, then merge when ready
cd ~/code/myproject.feature-api
# ... make changes ...
wt merge  # Auto-generates commit, runs tests, merges, removes worktree
```

**AI agent workflows:**
```bash
# Launch Claude on new feature
wt switch -c -x claude feature/refactor

# Launch OpenCode on another
wt switch -c -x opencode feature/optimization

# Monitor both agents
wt list
#   feature/refactor     🤖↑   (Claude working)
#   feature/optimization 💬↑   (OpenCode waiting)
```

**Quick branch switching:**
```bash
wt switch main           # Jump to main
wt switch -              # Switch to previous worktree
wt switch feature/test   # Jump to existing worktree
```

**Agent handoffs (background execution):**
```bash
# Spawn Claude in background tmux session
wtcc-bg fix-auth-bug "Fix authentication timeout issue"

# Spawn OpenCode in background
wtco-bg optimize-perf "Optimize database query performance"

# List background sessions
tmux ls

# Attach to agent session
tmux attach -t fix-auth-bug
```

This spawns AI agents in detached tmux sessions, allowing true parallel execution. One Claude session can hand off work to another that runs independently in the background.

**Stacked branches (incremental features):**
```bash
# Create feature-part1
wt switch -c feature-part1

# Work on part 1, then branch from current state
wtstack feature-part2  # Builds on feature-part1
```

**Cold start elimination:**
The `.config/wt.toml` post-create hook includes `wt step copy-ignored`, which copies gitignored files (caches, build artifacts, `.env`) from the main worktree. This dramatically speeds up new worktree creation.

To copy only specific patterns, create `.worktreeinclude`:
```gitignore
# .worktreeinclude — limits what gets copied
.env
.cache/
node_modules/
target/
```

**JSON output for scripting:**
```bash
wtj  # Alias for wt list --format=json

# Example: Count worktrees with uncommitted changes
wtj | jq '[.worktrees[] | select(.has_changes)] | length'

# Example: Get all branch names
wtj | jq -r '.worktrees[].branch'
```

### Advanced Patterns

**Dev server per worktree** (for web projects):
Each worktree gets a deterministic port using the `{{ branch | hash_port }}` template:
```toml
# .config/wt.toml (web projects)
[post-start]
server = "npm run dev -- --port {{ branch | hash_port }}"

[list]
url = "http://localhost:{{ branch | hash_port }}"
```

**Bare repository layout** (alternative structure):
Instead of sibling directories (`../repo.branch`), use a bare repo with worktrees as subdirectories:
```bash
git clone --bare <url> myproject/.git
cd myproject

# Configure worktrunk
cat > ~/.config/worktrunk/config.toml <<EOF
worktree-path = "{{ branch | sanitize }}"
EOF

# Create worktrees
wt switch -c main      # Creates myproject/main/
wt switch -c feature   # Creates myproject/feature/
```

### See Also

- [Worktrunk Documentation](https://worktrunk.dev)
- [Claude Code Integration](https://worktrunk.dev/claude-code/)
- [Worktrunk + Beads Integration](docs/worktrunk-beads-integration.md)

## OpenCode Configuration

OpenCode configuration is managed through nix-darwin with one exception:

**Plugin Management:**
- Plugins are NOT managed by nix (user-managed in `~/.config/opencode/plugin/`)
- See `config/opencode/README.md` for setup instructions
- See `config/opencode/AGENTS.md` for agent-facing documentation

**Required Plugins:**
- `opencode-jj` - https://github.com/edmundmiller/opencode-jj
- `boomerang-notify` - https://github.com/edmundmiller/boomerang-notify

**After `hey rebuild`:**
- Symlinked config files update automatically
- Tools get re-synced to `~/.config/opencode/tool/`
- Plugins are untouched (manual management)

## Notes

- Commands must be run from the repository root
- After major updates, run `hey gc` to clean old generations
- Host-specific settings override module defaults
- The system uses home-manager for user-level configuration
- **ALWAYS use the `hey` command** - it's a modular JustScript system that provides the primary interface to all nix-darwin operations
- Uses nix-darwin 25.05 with `system.primaryUser` set for proper user context
- **ALWAYS overwrite files directly** - never create underscore versions
