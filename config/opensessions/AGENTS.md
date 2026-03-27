# Opensessions Config - Agent Guide

## Purpose

This directory holds local opensessions configuration files that are loaded from `~/.config/opensessions` at runtime.

## Structure

```
config/opensessions/
├── AGENTS.md
└── plugins/
    └── pi.js
```

## Plugin Loading Contract

- opensessions loads local plugins from `~/.config/opensessions/plugins/`.
- Plugins are loaded with `require(...)`, so this repo uses **CommonJS** exports.
- `pi.js` must export a default factory shape via CommonJS:

```js
module.exports = function registerPlugin(api) {
  api.registerWatcher(...);
};
```

## `plugins/pi.js` behavior

- Registers watcher name: `pi`
- Watches Pi session transcripts under:
  - `~/.pi/agent/sessions/` (default)
  - `$PI_SESSIONS_DIR` (override)
- Resolves session mapping from the transcript `session.cwd` field via `ctx.resolveSession(...)`.
- Uses both:
  - recursive `fs.watch` (fast updates)
  - periodic polling fallback (resilience)

### Status mapping (important)

- User message => `running`
- Assistant `stopReason`:
  - `toolUse` / `tool_use` => `running`
  - `stop` / `end_turn` => `done`
  - `cancelled` / `aborted` / `interrupted` => `interrupted`
  - `error` / `failed` => `error`
- Pi custom status events:
  - `status=running` => `running`
  - `status=stopped && isIdle && !hasPendingMessages` => `done`
  - `status=stopped && hasPendingMessages` => `running`
  - other non-idle stopped states => `waiting`

### Thread identity

- `threadId`: parsed from transcript filename (UUID suffix if present)
- `threadName`: best-effort from
  1. `session_info.name`
  2. `pi-tmux-window-name/window` payload
  3. first user prompt text

## Editing notes

- Keep plugin dependency-free (Node/Bun built-ins only).
- Keep scanning incremental (`fileSize` deltas) to avoid rereading entire files.
- Do not emit events before initial seeding completes.
- Keep stale-start suppression (`STALE_MS`) so old sessions don’t flood sidebar state on startup.

## Integration point in this repo

- Symlink to home is declared in: `modules/shell/tmux/default.nix`
- Activated only when: `modules.shell.tmux.opensessions.enable = true;`
