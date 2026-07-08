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
| `prefix+A`                        | New jj workspace in tab     |
| `prefix+d`                        | Remove jj workspace         |
| `prefix+T`                        | Agent timeline              |
| `prefix+R`                        | Refresh GitHub PR status    |
| `prefix+I`                        | Start GitHub issue workflow |
| `prefix+O`                        | Start from GitHub item      |

Herdr defaults still provide other common actions such as rename workspace, rename tab, close tab, and close workspace. `prefix+g` uses Herdr's native worktree prompt; after creation, the `dotfiles.dev-layout` plugin handles Herdr's `worktree.created` event to seed the configured coding agent, Hunk, Neovim, and shell tabs. `prefix+G` opens existing worktrees.

## Plugins

Dotfiles-specific helper behavior lives in local Herdr plugins under `config/herdr/plugins/` and is registered by `modules/shell/herdr/default.nix`:

- `dotfiles.agent-read-command` — copies a `herdr agent read ...` command from pane/tab context menus.
- `dotfiles.dev-layout` — provides `prefix+u`/`prefix+U` Hunk actions plus the `worktree.created` dev-layout bootstrap action.
- `dotfiles.github-link-preview` — registers a GitHub issue/PR link handler that opens `gh issue view` or `gh pr view` in a Herdr side pane.

Marketplace/GitHub plugins are installed by activation when missing:

- `NathanFlurry/herdr-plugin-jj-workspace`
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
