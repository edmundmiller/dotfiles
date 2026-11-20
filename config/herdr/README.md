---
purpose: Explain native Herdr deployment, usage, and recovery.
applies_to: People changing or operating Herdr on Macs and servers.
entrypoint: Enable modules.shell.herdr; configure native app or core ownership.
verification: Native behavior tests and mod checks without activation.
update_when: Commands, preferences, mod links, or machine registration change.
---

# Herdr

`modules.shell.herdr.enable` selects native Herdr. `native.app.enable` defaults
to true on Macs and false on Linux servers, including the NUC. App hosts receive
preferences, personal mods and `herdr-dev`. Servers check for `hc` but receive
no app files or app helpers. Enable the app explicitly for a Linux desktop,
or disable it for a headless Mac.

The official installer owns `herdr-app`, `hc` and the signed app bundle. Nix
reports missing binaries but never downloads, patches or re-signs them.
Bootstrap a Mac with the official app installer, or a server with the core-only
installer at `https://releases.herdr.dev/core/install.sh`.
`native.coreCommand` defaults to `~/.local/bin/hc`. Use `hc update` to update
the core without stopping running terminals. Ghostty opens a plain shell
independently of Herdr.

## Preferences and layouts

`native/settings.json`, `native/keys.json` and `native/programs.json` own only
the leaves they contain. Activation deep-merges them into writable files under
`~/.config/herdr-app`. It preserves other preferences and refuses invalid JSON
instead of resetting it. Sounds default off. Fonts, theme, zoom and navigation
remain app-owned. Native Herdr cannot inherit Ghostty's `terminal` theme.

Ctrl+C opens the `dotfiles-prefix` menu. Press Ctrl+C again to send an interrupt,
or Escape to cancel. `prefix+q` only cancels. The menu provides pane navigation,
tabs, numbered spaces, agents, the picker and Hunk reviews. `prefix+f` opens the
native Files panel and `prefix+m` the native palette. Cmd+Shift+G or Ctrl+Shift+G
opens Dev tools. Existing app shortcuts remain, including Cmd+T, Cmd+D and
Cmd+Shift+P on macOS.

The personal `dotfiles` layout removes pane gaps, rounded corners and outer
borders without changing shipped layouts. App hosts also receive
[Herdr T3](native/t3/README.md). Ctrl+Shift+L alternates between `main` and
`herdr-t3` without changing the current layout during activation. The optional
T3 theme and pulls.review extra are not installed. In T3, Ctrl+C then Shift+B
switches Spaces/Agents or Focus, Shift+A opens single-agent view, and Shift+S
settles or unsettles the focused agent in Focus. Lowercase `b` toggles the
sidebar and `s` splits down.

On Linux, Ctrl+Shift+C copies selected text and Ctrl+Shift+V pastes text.
Hold Shift while dragging to select when a terminal program captures the mouse.
Ctrl+V invokes `terminal.paste_image`, not ordinary text paste.

## Checkout and review helpers

```sh
herdr-dev open /path/to/checkout
herdr-dev open /path/to/checkout --agent amp
herdr-dev hunk
herdr-dev hunk --staged
herdr-dev hunk --branch origin/main
```

`open` validates an existing Git checkout, runs its executable
`scripts/qmd-seed-worktree.sh` if present, then creates an agent space and Hunk
tab. The default agent follows `DEFAULT_CODING_AGENT`, falling back to Pi.
MacTraitor-Pro selects Amp and Seqeratop selects Pi. `--agent` overrides this.
Hunk reviews the invoking directory beside the focused local terminal.
The Dev tools panel uses the focused pane's directory. Remote and composition
panes are rejected. Failures report partial resources without deleting them.

Pi reports OSC 7501 status natively. Other agents need the same protocol to
appear as agents. Old socket hooks are removed for enabled runtimes.

The legacy TUI, plugins, review boxes, YAML layouts and workspace lifecycle
helpers are retired. There is no backend switch. Existing sessions, old config,
machine profiles and worktrees are not migrated or deleted. Native worktrees
use `~/.herdr/worktrees`, not `~/.local/share/herdr/worktrees`. Native recovery
starts shells, not the original agents. Preserve checkouts, bookmarks and
receipts when a native equivalent is unavailable. Shipped mods/layouts,
generated instructions, typings, click state and runtime documents stay
app-owned.

## Remote machines

`hnuc` opens a native remote shell; `hnuc t7` attaches an existing terminal.
Mac app hosts default to `native.machines.nuc = "emiller@nuc"`, using the existing
SSH alias. Activation registers missing machines after linking SSH config.
The app reads the same default core session. Registration preserves other
machines and sessions and refuses conflicting names. Failures warn and retry
on the next activation without blocking a rebuild or installing server files.
Set `native.machines = { };` to disable registration. Removing a declaration
does not delete a saved machine. Servers and headless Macs register none by default.

`herdr-studios list [--include-stopped]` lists SSH-enabled Seqera Studios across
workspaces. `sync` writes `seqera-studio-a<sessionId>` SSH aliases to
`~/.ssh/seqera-studios.conf` and uses `hc machine add --install` for running ones.
It preserves existing machines, including stopped or filtered Studios. Use
`--all-users` to include others' Studios, or `--dry-run` to preview without writes.
Tokens come from `TOWER_ACCESS_TOKEN`, `SEQERA_ACCESS_TOKEN`, or 1Password.
If SSH authentication fails, approve the key through a plain
`ssh seqera-studio-a<id> true`. Sync does not delete old remote installations.

## Checks and mod-link recovery

```sh
uv run --with pytest python -m pytest -q tests/test_herdr_native_config.py \
  tests/test_herdr_native_dev.py tests/test_herdr_studios_native.py
node --experimental-vm-modules --test config/herdr/native/mods/dotfiles-prefix/prefix.test.mjs
herdr-app check config/herdr/native/mods/dotfiles-prefix
herdr-app check config/herdr/native/mods/dotfiles-dev
hey check config/herdr modules/shell/herdr
```

Source checks neither install the panel nor activate preferences. An authorized
`hey re` applies managed files. Native JSON and mods reload live without a core
restart. Never stop an old server merely to apply native app configuration.

If a relative import resolves outside the application directory, inspect links:

```sh
ls -ld ~/.config/herdr-app/mods/dotfiles-prefix
ls -l ~/.config/herdr-app/mods/dotfiles-prefix/main.js \
  ~/.config/herdr-app/mods/dotfiles-prefix/prefix-bindings.js
herdr-app check ~/.config/herdr-app/mods/dotfiles-prefix
```

Herdr checks canonical paths. Home Manager's `recursive = true` creates a real
mod directory with individual file symlinks into `/nix/store`, so relative
imports resolve outside it even when repository source checks pass.
`modules/shell/herdr/native.nix` instead links each mod as a whole directory.
Keep whole-directory links for relative imports rather than inlining imports,
copying files manually or weakening path checks. T3 uses the same arrangement.

A source edit or push does not replace installed links. With activation
authority, run `hey re` on the target Mac. Home Manager preserves an old real
directory as `dotfiles-prefix.bkup`. Preserve that backup. On a backup collision,
inspect and preserve both versions instead of deleting either. Preserve manually
installed T3 directories and layouts before their first managed activation.

After activation, run `herdr-app check ~/.config/herdr-app/mods/dotfiles-prefix`
and `herdr-app status`. Open Ctrl+C and inspect the rendered menu. A CLI check
can toggle it with `herdr-app do mod.open --name dotfiles-prefix` and capture it
with `herdr-app shot`. Close with Escape. A source check or empty status error
list alone does not prove the installed menu loads. Preserve layout click state,
pins, folds and terminal labels throughout recovery.
