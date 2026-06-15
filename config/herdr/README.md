# Herdr

This directory tracks the user-facing Herdr config for these dotfiles.

Herdr is a terminal workspace manager/agent multiplexer. The upstream project reads config from:

```text
~/.config/herdr/config.toml
```

In this repo, the tracked source is:

```text
config/herdr/config.toml
```

`modules/shell/herdr.nix` uses that file as the template/source for the live config.

## Why the live config is writable

Unlike most files under `config/`, Herdr's live config is not a read-only symlink. Herdr can write onboarding and settings state back to `~/.config/herdr/config.toml`, so the Nix module keeps a writable copy and upserts the managed keys we care about.

Because of that:

- make intentional config changes in `config/herdr/config.toml`
- keep `modules/shell/herdr.nix` in sync when adding managed keys/helpers
- do not track transient Herdr state like `onboarding = false`

## Current keybindings

Prefix:

```text
ctrl+c
```

Custom/current mappings:

| Key        | Action                       |
| ---------- | ---------------------------- |
| `prefix+w` | New workspace                |
| `prefix+g` | New worktree                 |
| `prefix+G` | Open existing worktree       |
| `prefix+O` | Workspace picker             |
| `prefix+-` | Split horizontally           |
| `prefix+b` | Toggle sidebar               |
| `prefix+p` | Previous tab                 |
| `prefix+n` | Next tab                     |
| `prefix+u` | Open Hunk in a focused split |
| `prefix+U` | Open Hunk in a new tab       |

Herdr defaults still provide other common actions such as rename workspace, new tab, split vertical, close pane, fullscreen, and resize mode. `prefix+w` intentionally overrides Herdr's default workspace picker binding; the picker is moved to `prefix+O` to keep reloads clean. `prefix+g` uses Herdr's native worktree prompt; after creation, the `dotfiles.dev-layout` plugin handles Herdr's `worktree.created` event to seed Pi, Hunk, Neovim, and shell tabs. `prefix+G` opens existing worktrees.

## Plugins

Dotfiles-specific helper behavior lives in local Herdr plugins under `config/herdr/plugins/` and is registered by `modules/shell/herdr/default.nix`:

- `dotfiles.dev-layout` — provides `prefix+u`/`prefix+U` Hunk actions plus the `worktree.created` dev-layout bootstrap action.
- `dotfiles.github-link-preview` — registers a GitHub issue/PR link handler that opens `gh issue view` or `gh pr view` in a Herdr side pane.

## Reloading after edits

After editing the live config or applying a rebuild, reload the running Herdr server:

```bash
herdr server reload-config
```

A successful reload returns `status: applied`.

## Notes

Do not bind actions to plain printable keys such as `w`, `s`, `p`, or `n`; Herdr 0.6 disables those unsafe direct bindings because they intercept normal typing. Use `prefix+...` bindings, and avoid key sequences already claimed by Herdr defaults unless you intentionally want to replace them.
