# opencode-tmux-namer

## Purpose

OpenCode plugin that dynamically renames tmux windows based on project context and agent status.

## Directory Structure

```
packages/opencode-tmux-namer/
├── src/
│   └── index.ts      # Main plugin implementation (TypeScript source)
├── package.json      # Plugin metadata, scripts, dependencies
├── tsconfig.json     # TypeScript configuration
├── bun.lock          # Lockfile for reproducible builds
├── default.nix       # Nix derivation (builds with bun)
├── AGENTS.md         # This file
└── README.md         # User documentation
```

## Build System

**Nix-managed:** This plugin is built automatically via `hey rebuild`.

The nix derivation (`default.nix`) uses bun to:

1. Install dependencies from bun.lock
2. Compile TypeScript to dist/
3. Output `dist/` and `package.json` to the nix store

The built plugin is symlinked to `~/.config/opencode/plugin/opencode-tmux-namer` by `modules/shell/opencode.nix`.

## Development Commands

For local development/testing:

```bash
nix build .#packages.aarch64-darwin.opencode-tmux-namer  # Build via nix
hey rebuild                                                # Full system rebuild
```

To iterate quickly without rebuilding:

```bash
cd packages/opencode-tmux-namer
bun install && bun run build
# Then copy dist/ to ~/.config/opencode/plugin/opencode-tmux-namer/
```

**Important:** After editing `src/index.ts`, run `hey rebuild` to deploy changes.

## Plugin Events Used

- `session.status` - Real-time busy/idle/waiting status
- `session.idle` - Agent finished working
- `file.edited` - Track file changes for context
- `command.executed` - Track commands for intent inference
- `todo.updated` - Track todos for context
- `permission.updated` / `permission.replied` - Detect waiting state

## Status Icons

| Icon | Status  | Trigger                                             |
| ---- | ------- | --------------------------------------------------- |
| `●`  | Busy    | session.status = running/streaming                  |
| `□`  | Idle    | session.status = idle/completed, session.idle event |
| `■`  | Waiting | permission.updated, permission.replied              |
| `▲`  | Error   | session.status = error/failed                       |
| `◇`  | Unknown | Default/no status                                   |

## Naming Logic

1. **Project**: package.json name > git remote > directory name
2. **Intent**: Inferred from signals (test, debug, fix, refactor, doc, review, ops, spike, feat)
3. **Tag**: Inferred from signals (auth, api, db, cache, ui, nf, nix, term)

## Environment Variables

```bash
OPENCODE_TMUX_DEBUG=1              # Enable debug logging
OPENCODE_TMUX_COOLDOWN_MS=300000   # 5min between renames
OPENCODE_TMUX_DEBOUNCE_MS=5000     # 5s debounce
OPENCODE_TMUX_SHOW_STATUS=1        # Include status icons
OPENCODE_TMUX_WORKMUX_AWARE=1      # Detect workmux worktrees
OPENCODE_TMUX_WORKMUX_FORMAT=both  # branch|project|both
```

## Relation to tmux-opencode-integrated

This is a **native OpenCode plugin** with direct event access.
`tmux-opencode-integrated` is an **external Python script** that pattern-matches pane content.

Use both:

- This plugin for accurate status (has direct event access)
- tmux-opencode-integrated for Agent Management Panel (`<prefix> A`)

## Key Functions in src/index.ts

| Function              | Purpose                                             |
| --------------------- | --------------------------------------------------- |
| `TmuxNamer`           | Main plugin factory, exported as default            |
| `loadConfig()`        | Load env vars into PluginConfig                     |
| `findTmux()`          | Locate tmux binary                                  |
| `getWorkmuxContext()` | Detect workmux worktree, extract branch/project     |
| `getProjectName()`    | Extract project name from pkg.json/git/dir          |
| `inferIntent()`       | Pattern match signals → intent (feat/fix/debug/etc) |
| `inferTag()`          | Pattern match signals → tag (auth/api/db/etc)       |
| `buildName()`         | Construct name string (workmux-aware)               |
| `renameWindow()`      | Call `tmux rename-window`                           |
| `mapSessionStatus()`  | Map OpenCode status strings → Status enum           |

## Workmux Integration

Detects workmux worktrees via `git rev-parse --git-dir` checking for `/worktrees/` path.
When detected, naming switches to branch-focused format matching workmux conventions.
Workmux config uses same icons for consistency.

## Adding New Intents/Tags

Edit `inferIntent()` or `inferTag()` in `src/index.ts`:

```typescript
// Add new intent pattern
if (/\b(migrate|migration|schema)\b/.test(t)) return "migrate";

// Add new tag pattern
[/\b(graphql|gql)\b/, "gql"],
```

Then rebuild: `bun run build`
