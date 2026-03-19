---
purpose: Define the tmux-native workspace model inspired by cmux concepts.
applies_to: Changes to tmx, cmux-concept.conf, or tmux workspace conventions.
entrypoint: bin/tmx and config/tmux/cmux-concept.conf.
verification: Check bin/tmx syntax and load cmux-concept.conf in an isolated tmux server.
update_when: Workspace names, keybindings, bootstrap behavior, or ownership changes.
---

# tmux-native strategy inspired by cmux concepts

This plan borrows **organization habits** from cmux while staying fully tmux-native.

> Context: cmux does not attach to external tmux sessions as part of its own UI model. Its tmux compatibility layer is command emulation, not tmux server/session attachment.

## Concept mapping (cmux → tmux)

| cmux                            | tmux equivalent                        | Practical note                            |
| ------------------------------- | -------------------------------------- | ----------------------------------------- |
| Window                          | Session                                | Top-level container for a project/context |
| Workspace (tab)                 | Window                                 | Best 1:1 mental model in tmux             |
| Pane                            | Pane                                   | Direct match                              |
| Surface (tab stack inside pane) | Popup / zoomed pane / temporary window | No native tmux surface layer              |
| Panel (sidebar/tool UI)         | choose-tree, status line, popup menus  | Partial equivalent                        |

## tmux-native operating model

- **Session = project** (`dotfiles`, `api`, `infra`)
- **Window = workspace** (`code`, `test`, `logs`, `ops`)
- **Pane = role** within a workspace (editor, runner, shell)
- **Popup/zoom = temporary surface** (git TUI, scratch shell, picker)

This gives you cmux-style structure with standard tmux primitives.

## What this worktree adds

- `bin/tmx` — bootstrap/switch helper for project sessions with canonical workspace windows
- `config/tmux/cmux-concept.conf` — optional tmux snippet for workspace navigation + alert flow

## Quick start

```bash
# 1) bootstrap/attach a project session from repo root
bin/tmx

# 2) explicit session + path
bin/tmx work ~/.config/dotfiles

# 3) load optional keybindings in a live tmux server
tmux source-file ~/.config/tmux/cmux-concept.conf
```

## Suggested shell aliases (optional)

```bash
alias tmx='~/bin/tmx'
alias tls='tmux ls'
alias ta='tmux attach -t'
alias tk='tmux kill-session -t'
```

## Optional when tmux is nested inside cmux

Keep this tmux-native plan as primary. If nested in cmux, passthrough helps notifications:

```tmux
set -g allow-passthrough on
```

## Profiles

### Starter profile (minimal)

- Use `tmx` for session bootstrap
- Keep canonical windows: `code`, `test`, `logs`, `ops`
- Use `choose-tree` + `last-window` for quick workspace hops
- Enable activity + silence alerts

### Power-user profile (advanced)

- Use popup "surfaces" for transient tools (git TUI, scratch shell, file picker)
- Add alert hooks to desktop notifications
- Add `tmux-resurrect`/`tmux-continuum` for session metadata/layout restore
- Add per-project `tmx` wrappers with startup commands

## Migration steps from a typical tmux setup

1. Keep existing keybindings; add only canonical window naming.
2. Start using `tmx` for new sessions.
3. Source `cmux-concept.conf` and test quick nav keys.
4. Move ad-hoc commands into popups/temporary windows (surface habit).
5. Standardize project session naming and window template.
6. (Optional) enable passthrough if running tmux inside cmux.
