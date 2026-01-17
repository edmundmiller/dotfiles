# jjui Configuration - Agent Guide

## Overview

jjui is the TUI for jj version control. Config at `~/.config/jjui/config.toml`.

## Key Facts

1. **Leader keys are DEPRECATED** - Use `key_sequence` instead (shows overlay UI)
2. **Custom commands** use either `args` (jj subcommand) or `lua` (scripting)
3. **Theme**: Catppuccin Mocha (dark, warm colors)
4. **jj aliases are exposed** as custom commands (aid, aide, wip, tug, etc.)

## File Structure

```
config/jjui/
├── config.toml   # Main configuration
├── README.md     # Human documentation
└── AGENTS.md     # This file
```

## Custom Command Patterns

### Key Sequence (multi-key, shows overlay)
```toml
[custom_commands."ai describe"]
key_sequence = ["a", "d"]
desc = "AI-generated commit message"
args = ["aid"]
```

### Single Key
```toml
[custom_commands.yank]
key = ["Y"]
desc = "Copy to clipboard"
lua = '''...'''
```

## Important Key Bindings

| Binding | Purpose | Implementation |
|---------|---------|----------------|
| `a d/e` | AI commit messages | Calls `jj aid`/`jj aide` alias |
| `Y` | Context-aware copy | Lua: copies file/change_id/checked files |
| `ctrl+l` | Revset switcher | Lua: choose() menu |
| `alt+j/k` | Move commits | rebase --insert-before/after |
| `O` | Open in editor | Lua: suspend + nvim |

## Dependencies

- jj aliases: `aid`, `aide`, `wip`, `tug`, `retrunk`, `cleanup`, `tidy`, `sync`, `nd`, `spr`
- All defined in `config/jj/config.toml`

## Gotchas

1. **Lua `context` API**: Use `context.change_id()`, `context.file()`, `context.checked_files()`
2. **Flash messages**: Use `flash("message")` for user feedback
3. **Refresh after changes**: Call `revisions.refresh()` after jj commands that modify state
4. **suspend()**: Required before launching external programs (nvim, etc.)

## When Editing

- Test with `jjui --check-config` before committing
- Key conflicts: check default keys in jjui docs
- Lua errors: check syntax carefully, no type system to help
