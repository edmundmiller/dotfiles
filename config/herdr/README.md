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

| Key        | Action                                    |
| ---------- | ----------------------------------------- |
| `prefix+w` | New workspace                             |
| `prefix+s` | Split horizontally                        |
| `prefix+q` | Toggle sidebar (prevents accidental quit) |
| `prefix+p` | Previous tab                              |
| `prefix+n` | Next tab                                  |
| `prefix+[` | Open Hunk in a focused split              |
| `prefix+]` | Open Hunk in a new tab                    |

Herdr defaults still provide other common actions such as new tab, split vertical, close pane, fullscreen, and resize mode. `prefix+q` is deliberately bound to sidebar toggle so it intercepts Herdr's hard-coded quit/detach fallback.

## Helpers

Two repo scripts back the custom command bindings:

- `bin/herdr-tab` — implements prefix-only previous/next tab movement using Herdr's socket API.
- `bin/herdr-hunk` — opens Hunk from the active Herdr context, either in a focused split or a new tab.

## Reloading after edits

After editing the live config or applying a rebuild, reload the running Herdr server:

```bash
herdr server reload-config
```

A successful reload returns `status: applied`.

## Notes

Do not bind Herdr's built-in `previous_tab` / `next_tab` to plain `p` / `n`; those are terminal-direct and will steal normal typing. Use the `[[keys.command]]` bindings with `herdr-tab` instead.
