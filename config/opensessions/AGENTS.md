# Opensessions Config - Agent Guide

## Purpose

This directory holds local opensessions configuration files that are loaded from `~/.config/opensessions` at runtime.

## Structure

```
config/opensessions/
├── AGENTS.md
└── plugins/
    └── hunk.js
```

## Plugin Loading Contract

- opensessions loads local plugins from `~/.config/opensessions/plugins/`.
- Plugins are loaded with `require(...)`, so this repo uses **CommonJS** exports.
- This repo currently ships only one local plugin: `hunk.js`.
- Pi support is native in upstream opensessions and no longer requires a local `pi.js` plugin.

## `plugins/hunk.js` behavior

- Registers watcher name: `hunk`
- Polls the local Hunk MCP endpoint (`http://127.0.0.1:47657/session-api` by default)
- Maps active Hunk sessions to tmux sessions via `ctx.resolveSession(...)`
- Emits:
  - `running` while session appears in Hunk API list
  - `done` after a tracked session disappears

## Editing notes

- Keep plugin dependency-free (Node/Bun built-ins only).
- Keep scanning incremental (`fileSize` deltas) to avoid rereading entire files.
- Do not emit events before initial seeding completes.
- Keep stale-start suppression (`STALE_MS`) so old sessions don’t flood sidebar state on startup.

## Integration point in this repo

- Symlink to home is declared in: `modules/shell/tmux/default.nix`
- Activated only when: `modules.shell.tmux.opensessions.enable = true;`
