# Rex

`init.lua` uses the tmux/Herdr `Ctrl+C` prefix and Ghostty resize shortcuts.
`modules.desktop.term.rex.enable` deploys it to `~/.config/rex/init.lua` on both Macs.
Install the Rex beta app separately. `env.zsh` adds the bundled CLI to `PATH`
from `/Applications` or `~/Applications`, so shells and tools launched from them
(including Pi's Rex extension) can run `rex`. Ghostty startup is unchanged.

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
