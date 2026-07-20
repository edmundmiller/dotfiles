---
purpose: Explain the managed Herdr configuration and task-workspace workflow.
applies_to: People changing or operating Herdr in these dotfiles.
entrypoint: Start with config/herdr/config.toml.
verification: Rebuild, reload config, and inspect plugin and tab state.
update_when: Herdr keys, plugins, lifecycle, or runtime paths change.
---

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

`modules/shell/herdr/default.nix` uses that file as the template/source for the live config.

## Why the live config is writable

Unlike most files under `config/`, Herdr's live config is not a read-only symlink. Herdr can write onboarding and settings state back to `~/.config/herdr/config.toml`, so the Nix module keeps a writable copy and upserts the managed keys we care about.

Because of that:

- make intentional config changes in `config/herdr/config.toml`
- keep `modules/shell/herdr/default.nix` in sync when adding managed keys/helpers
- do not track transient Herdr state like `onboarding = false`

## Current keybindings

Prefix:

```text
ctrl+c
```

Custom/current mappings:

| Key                               | Action                      |
| --------------------------------- | --------------------------- |
| `prefix+comma`                    | Settings                    |
| `prefix+ctrl+r`                   | Reload config               |
| `prefix+w`                        | Workspace picker            |
| `prefix+N`                        | New workspace               |
| `prefix+g`                        | New worktree                |
| `prefix+G`                        | Open existing worktree      |
| `prefix+/`                        | Goto/navigation             |
| `prefix+c`                        | New tab                     |
| `prefix+alt+t`                    | Rename tab                  |
| `prefix+1..9`                     | Switch tab                  |
| `prefix+h/j/k/l`                  | Focus pane                  |
| `prefix+ctrl+w`                   | Last pane                   |
| `prefix+tab` / `prefix+shift+tab` | Cycle panes                 |
| `prefix+s`                        | Split horizontally          |
| `prefix+v`                        | Split vertically            |
| `prefix+x`                        | Close pane                  |
| `prefix+z`                        | Zoom pane                   |
| `prefix+r`                        | Resize mode                 |
| `prefix+enter`                    | Edit scrollback             |
| `prefix+b`                        | Toggle sidebar              |
| `prefix+p`                        | Previous tab                |
| `prefix+n`                        | Next tab                    |
| `prefix+m`                        | Command palette             |
| `prefix+f`                        | File viewer in a split      |
| `prefix+F`                        | File viewer in a tab        |
| `prefix+]`                        | Hunk worktree diff          |
| `prefix+}`                        | Hunk staged diff            |
| `prefix+{`                        | Hunk branch diff            |
| `prefix+u`                        | Dotfiles Hunk split         |
| `prefix+U`                        | Dotfiles Hunk tab           |
| `prefix+a`                        | New jj workspace            |
| `prefix+d`                        | Remove clean closed-PR jj workspace |
| `prefix+D`                        | Abandon clean jj workspace with typed confirmation |
| `prefix+T`                        | Agent timeline              |
| `prefix+R`                        | Refresh GitHub PR status    |
| `prefix+I`                        | Start GitHub issue workflow |
| `prefix+O`                        | Start from GitHub item      |

Herdr defaults still provide other common actions. `prefix+a` creates a task-named jj workspace; `prefix+g` is the native Git fallback. The `dotfiles.dev-layout` plugin handles `workspace_created` and `worktree_created`, creating exactly OMP and Hunk tabs and focusing OMP.

## Plugins

Dotfiles-specific helpers live under `packages/herdr-plugins/` and are registered by `modules/shell/herdr/default.nix`:

- `dotfiles.agent-read-command` — copies a `herdr agent read ...` command from pane/tab context menus.
- `dotfiles.dev-layout` — provides Hunk actions plus the idempotent two-tab checkout bootstrap.
- `dotfiles.github-link-preview` — opens GitHub issue/PR previews in a Herdr side pane.

The jj workspace plugin is pinned to `edmundmiller/herdr-plugin-jj-workspace` commit `ec8fde27e0cf4664012b585ebc2dc7cb0934ee1b` while upstream PR #4 is open. Activation installs other marketplace plugins when missing:

- `smarzban/herdr-file-viewer`
- `dutifuldev/ghzinga/plugins/herdr`
- `dcolinmorgan/herdr-remote/relay`
- `razajamil/herdr-plugin-workspace-manager`
- `paulbkim-dev/vim-herdr-navigation`
- `ogulcancelik/herdr-plugin-github-start`
- `rjyo/herdr-window-title-sync`
- `wyattjoh/herdr-plugin-gh-pr`
- `kkckkc/herdr-plugin-gh-workflow`
- `alon-z/herdr-command-palette`
- `0x5c0f/herdr-insight`

## Reloading after edits

After editing the live config or applying a rebuild, reload the running Herdr server:

```bash
herdr server reload-config
```

A successful reload returns `status: applied`.

## Notes

Do not bind actions to plain printable keys such as `w`, `s`, `p`, or `n`; Herdr 0.6 disables those unsafe direct bindings because they intercept normal typing. Use `prefix+...` bindings, and avoid key sequences already claimed by Herdr defaults unless you intentionally want to replace them.
