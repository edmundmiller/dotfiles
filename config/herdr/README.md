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

| Key                               | Action                                             |
| --------------------------------- | -------------------------------------------------- |
| `prefix+comma`                    | Settings                                           |
| `prefix+ctrl+r`                   | Reload config                                      |
| `prefix+w`                        | Workspace picker                                   |
| `prefix+N`                        | New workspace                                      |
| `prefix+g`                        | New worktree                                       |
| `prefix+G`                        | Open existing worktree                             |
| `prefix+/`                        | Goto/navigation                                    |
| `prefix+c`                        | New tab                                            |
| `prefix+alt+t`                    | Rename tab                                         |
| `prefix+1..9`                     | Switch tab                                         |
| `prefix+h/j/k/l`                  | Focus pane                                         |
| `prefix+ctrl+w`                   | Last pane                                          |
| `prefix+tab` / `prefix+shift+tab` | Cycle panes                                        |
| `prefix+s`                        | Split horizontally                                 |
| `prefix+v`                        | Split vertically                                   |
| `prefix+x`                        | Close pane                                         |
| `prefix+z`                        | Zoom pane                                          |
| `prefix+r`                        | Resize mode                                        |
| `prefix+enter`                    | Edit scrollback                                    |
| `prefix+b`                        | Toggle sidebar                                     |
| `prefix+p`                        | Previous tab                                       |
| `prefix+n`                        | Next tab                                           |
| `prefix+m`                        | Command palette                                    |
| `prefix+f`                        | File viewer in a split                             |
| `prefix+F`                        | File viewer in a tab                               |
| `prefix+]`                        | Hunk worktree diff                                 |
| `prefix+}`                        | Hunk staged diff                                   |
| `prefix+{`                        | Hunk branch diff                                   |
| `prefix+u`                        | Dotfiles Hunk split                                |
| `prefix+U`                        | Dotfiles Hunk tab                                  |
| `prefix+a`                        | New jj workspace                                   |
| `prefix+d`                        | Remove clean closed-PR jj workspace                |
| `prefix+D`                        | Abandon clean jj workspace with typed confirmation |
| `prefix+t`                        | Smart rename current agent tab                     |
| `prefix+T`                        | Agent timeline                                     |
| `prefix+R`                        | Refresh GitHub PR status                           |
| `prefix+I`                        | Start GitHub issue workflow                        |
| `prefix+O`                        | Start from GitHub item                             |
| `prefix+B`                        | Open Herdr Browser in a right split                |

Herdr defaults still provide other common actions. `prefix+a` creates a task-named jj workspace; `prefix+g` is the native Git fallback. The `dotfiles.dev-layout` plugin serializes `workspace.created` and `worktree.created` per workspace. It creates and focuses OMP everywhere, and adds Hunk only when the workspace is inside a Git checkout.

Herdr-launched agents also inherit the Nix-packaged `rift` CLI for experimental copy-on-write workspace trials. Rift is not bound to a key and does not replace native Git or jj workspace lifecycle.

## Herdr 0.8.0 lifecycle

`[worktrees].post_create_command` is obsolete here. Activation removes that key;
worktree automation belongs in plugin `[[events]]` hooks.

Herdr emits these lifecycle sequences:

| Operation         | Relevant events                                                        |
| ----------------- | ---------------------------------------------------------------------- |
| `worktree.create` | `workspace.created`, `tab.created`, `pane.created`, `worktree.created` |
| `worktree.open`   | `worktree.opened`; creation events when a workspace must be opened     |
| `worktree.remove` | `worktree.removed`; `workspace.closed` when the workspace was open     |

Current and potential repo uses:

- `dotfiles.dev-layout` already uses `worktree.created` for native Git checkout bootstrap and `workspace.created` for ordinary or jj-created Herdr workspaces. Its lock and idempotence absorb the create sequence safely.
- `worktree.opened` would fit rehydrating plugin-owned state when an existing checkout opens. No separate hook is needed now because layout state persists and a newly opened workspace emits `workspace.created`.
- `worktree.removed` would fit deleting plugin-owned per-checkout cache. Do not use it to replace the explicit safe removal in the `done` skill; no such cache exists today.
- Smart rename should remain on `workspace.created` and `tab.created`; it is workspace/tab lifecycle, not Git checkout lifecycle.

Inspect the version-matched event schema with `herdr api schema --json`. Event
hooks receive `HERDR_PLUGIN_EVENT`, `HERDR_PLUGIN_EVENT_JSON`, and
`HERDR_PLUGIN_CONTEXT_JSON`.

## Plugins

Repo-owned plugins are composed into a local package and registered by `modules/shell/herdr/default.nix`:

- `dotfiles.agent-read-command` — copies a `herdr agent read ...` command from pane/tab context menus.
- `dotfiles.dev-layout` — provides Hunk actions plus idempotent OMP bootstrap, adding Hunk only for Git checkout workspaces.
- `dotfiles.github-link-preview` — opens GitHub issue/PR previews in a Herdr side pane.
- `nathanflurry.jj-workspace` — built from a pinned upstream revision plus the ordered safety patch under `packages/herdr-plugin-jj-workspace/`.
- `tab-smart-rename` — built from pinned upstream plus OMP and automatic-worker patches under `packages/herdr-tab-smart-rename/`. It reuses OMP's configured provider and authentication; no separate key is required.

Herdr 0.8.0 makes installed/linked plugins and enabled state global per user.
The module therefore owns one `~/.config/herdr/plugins.json`, not per-session
registries.

Marketplace/GitHub plugins are installed by activation when missing:

- `smarzban/herdr-file-viewer`
- `dutifuldev/ghzinga/plugins/herdr`
- `dcolinmorgan/herdr-remote/relay`
- `razajamil/herdr-plugin-workspace-manager`
- `paulbkim-dev/vim-herdr-navigation`
- `ogulcancelik/herdr-plugin-github-start`
- `ogulcancelik/herdr-browser`
- `rjyo/herdr-window-title-sync`
- `wyattjoh/herdr-plugin-gh-pr`
- `kkckkc/herdr-plugin-gh-workflow`
- `alon-z/herdr-command-palette`
- `0x5c0f/herdr-insight`

The smart-rename worker starts idempotently during activation and on `workspace.created` or `tab.created`. `prefix+t` remains the explicit current-tab override.

## Reloading after edits

After editing the live config or applying a rebuild, reload the running Herdr server:

```bash
herdr server reload-config
```

A successful reload returns `status: applied`.

## Notes

Do not bind actions to plain printable keys such as `w`, `s`, `p`, or `n`; Herdr 0.6 disables those unsafe direct bindings because they intercept normal typing. Use `prefix+...` bindings, and avoid key sequences already claimed by Herdr defaults unless you intentionally want to replace them.
