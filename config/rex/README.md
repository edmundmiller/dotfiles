# Rex

`init.lua` uses the tmux/Herdr `Ctrl+C` prefix and Ghostty resize shortcuts.
`modules.shell.rex.enable` deploys it to `~/.config/rex/init.lua` on both Macs.
Install the Rex beta app separately. `env.zsh` adds the bundled CLI to `PATH`
from `/Applications` or `~/Applications`, so shells and tools launched from them
(including Pi's Rex extension) can run `rex`. Ghostty startup is unchanged.

## Appearance

The Rex module pins vertical tabs on both Macs and selects themes using the
host's existing `modules.desktop.term.themeStack.variant`:

| Host           | Variant      | Light            | Dark             |
| -------------- | ------------ | ---------------- | ---------------- |
| MacTraitor Pro | `catppuccin` | Catppuccin Latte | Catppuccin Mocha |
| Seqeratop      | `seqera`     | SeqeraLight      | SeqeraDark       |

`themes-catppuccin.json` preserves the exact palettes imported from Ghostty on
MacTraitor Pro, including their custom IDs. `themes-seqera.json` maps the colors
from `config/ghostty/themes/SeqeraLight` and `SeqeraDark` into the same Rex JSON
format. These are palette snapshots, not live links to Ghostty's theme files.
The module derives the selected light/dark IDs from the chosen snapshot.

Rex stores these app preferences separately from `init.lua`. Nix sets the tab
style and selected theme IDs through macOS defaults. Home Manager writes the
theme JSON as NSData, the format Rex expects. It replaces the custom-theme list
on each activation; additional imports must be captured here to keep them.
Other Rex preferences and the appearance-mode selection are left alone.

Apply with an authorized `hey re`, with Rex quit, then reopen Rex. A Lua config
reload does not apply these preferences. To change the pinned themes, import
them in Rex, export only `Workspace.customThemes` from `com.superlogical.rex`
into the appropriate `themes-<variant>.json`, keeping one light and one dark
theme. Do not commit the whole preferences domain; it contains unrelated app
state.

## Shortcuts

| Keys                                   | Action                             |
| -------------------------------------- | ---------------------------------- |
| `Ctrl+C`, then `Ctrl+C`                | Send an interrupt to the terminal  |
| Prefix + `c`, `n`, `p`                 | New, next, previous tab            |
| Prefix + `s`, `v`                      | Split below, right                 |
| Prefix + `h/j/k/l`                     | Focus left/down/up/right           |
| Prefix + `x`, `z`                      | Close pane/tab/window, toggle zoom |
| Prefix + `w`, `b`                      | Switch session, toggle sidebar     |
| `Ctrl+Shift+H/J/K/L`                   | Resize by 10                       |
| Prefix + `r`                           | Enter resize mode                  |
| Resize mode `h/j/k/l`, `Shift+H/J/K/L` | Resize, resize by 15               |
| Resize mode `=`, `Enter` or `Escape`   | Balance panes, leave mode          |

Bare `Ctrl+H/J/K/L` pass through to terminal applications. Other Rex shortcuts
keep their client defaults, including the `Cmd+Shift+P` command palette.

Validate a draft on a Mac with Rex installed:

```sh
rex config check config/rex/init.lua
```

The macOS `rex-config` pre-commit hook runs this check whenever `init.lua`
changes. `hey check config/rex` runs it too. It finds the CLI on `PATH` or in
Rex's app bundle under `/Applications` or `~/Applications`. Missing Rex fails
with an installation hint. Linux omits this hook. Re-enter the dev shell to
refresh installed hooks after changing `flake.nix`.

This checks Lua loading against the installed CLI without contacting a server.
It does not check client actions, ineffective unbinds, or focus callbacks.

After an authorized `hey re`, run these on the machine running the Rex server:

```sh
rex config check
rex config reload
rex keymap
```

Rex does not watch the file. `rex keymap` reports server-side binding warnings,
including ineffective unbinds. To also validate client actions and merged
shortcuts, pass the client's keymap request with `rex keymap --request FILE`.
Without that request, it only checks the config's bindings. Shortcuts set in
the app override this file.

Neither command exercises the focus callbacks. Inspect the installed server's
arguments with `rex api describe session.focus_direction`, then test all four
prefix + `h/j/k/l` directions in a split layout. Check that double `Ctrl+C`
interrupts a foreground command and bare `Ctrl+H/J/K/L` reach the terminal.
In resize mode, check that unbound keys do not type into the terminal and that
both `Enter` and `Escape` exit the mode.

Reference: [Rex configuration](https://www.superlogical.com/rex/docs/customize/config).
