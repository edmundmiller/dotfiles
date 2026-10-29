# Rex

`init.lua` uses the tmux/Herdr `Ctrl+C` prefix and Ghostty resize shortcuts.
`modules.shell.rex.enable` deploys it to `~/.config/rex/init.lua` on both Macs.
Install the Rex beta app separately. `env.zsh` adds the bundled CLI to `PATH`
from `/Applications` or `~/Applications`, so shells and tools launched from them
(including Pi's Rex extension) can run `rex`. Ghostty startup is unchanged.

## Daily jj workflow

Rex owns task sessions; jj owns their checkouts. Set `AGENT` to one executable
name or path in your shell environment. Use an executable wrapper for flags;
`AGENT=1` is not an agent selection. Herdr remains available separately.

| Keys               | Action                                                 |
| ------------------ | ------------------------------------------------------ |
| Prefix + `a`       | Prompt for a task slug and base, then open its session |
| Prefix + `Shift+A` | Reopen the focused checkout's recorded session         |
| Prefix + `d`       | Open a fresh review tab for the focused checkout       |
| Prefix + `w`       | Switch between existing task sessions                  |

The command palette also exposes these as **New jj task workspace**,
**Open jj workspace session**, and **Review jj workspace**. The launcher opens
in a separate terminal, so it never sends shell commands into a running agent.
It keeps its result visible. Close that launcher tab when finished.

The same workflow is scriptable after activation:

```sh
rex-jj new issue-123-login --repo ~/src/project --base 'trunk()'
rex-jj open /path/to/existing/task
rex-jj review /path/to/existing/task
```

`new` creates a named jj workspace and bookmark without fetching. Workspaces
live under `${XDG_DATA_HOME:-~/.local/share}/rex/workspaces/<repo-key>/<task>`;
creation from a child uses the same repository key. A stack uses its parent
bookmark as `--base`. Existing task names and destinations are rejected.
Git-only checkouts are rejected rather than initialized or converted.

Each session has `review` and `agent` tabs, with the agent active. `open` reuses
the recorded session even after a rename; after a session is closed, it creates
one for the existing checkout. Closing Rex tabs never deletes the workspace.
The helper stores session IDs and `receiptPath` in `.jj/rex-session.json`.
`agent-run` writes the durable receipt outside the checkout. If opening Rex
fails after creation, the helper keeps the workspace and prints its resume path.

The keybinding asks the invoking Mac client to select the new session. Remote
Control must be enabled in Rex. CLI calls print JSON without changing the app;
pass `--client CLIENT_ID` to select it, or use prefix + `w`.

With jj 0.46 and a colocated source, jj creates colocated children by default.
Hunk runs only when Git and jj both report the task checkout as their root.
On older jj, or in a non-colocated child, review shows `jj diff --git` instead.
That view is a snapshot; prefix + `d` refreshes it in a new tab. For an existing
non-colocated child on jj 0.46, verify `pwd` and `jj root`, run
`jj git colocation enable`, then reopen review. Never use `jj git init` to
convert an agent-created Git-only worktree.

Run these commands on the machine holding the checkout. The Mac module does
not install this workflow on the NUC; remote use requires the helper, agent,
jj, and configuration on that server first.

Review, publish, and cleanup follow the
[Rex jj skill](../../skills/catalog/using-rex-jj-workspaces/SKILL.md).
There is deliberately no delete-workspace key. Cleanup requires explicit
authority, preserved changes, and a closed or merged PR before forgetting a
workspace or removing its directory. Closing a session alone is not cleanup.

Validate with `python3 -m unittest tests.test_rex_jj_workspace` on a Mac with
Rex and jj installed. Tests start isolated Rex servers and disposable repos;
they do not reload or stop your running Rex. Run `hey check config/rex
modules/shell/rex.nix tests/test_rex_jj_workspace.py` for source checks.
Activation still requires an authorized `hey re`, followed by
`rex config reload`. The helper and these actions are not live before that.

## NUC connection

`init.lua` declares `nuc` at `https://nuc-rex.cinnamon-rooster.ts.net`, using
the host ID already registered in the Mac app. Keep that ID stable when renaming
the host. The shared Mac config makes this host available on both Macs.

`hosts/nuc/default.nix` enables Rex's separate `nuc-rex` Tailscale identity at
startup. It leaves the NUC's existing Tailscale Serve/Funnel configuration alone
and permits only the identity's owner. Enrollment is one-time runtime state;
the Nix configuration contains no auth key. The service runs as `emiller:users`
with an owner-only local socket, so new terminals use the NUC user's home,
shell, files, and permissions. Rex's state stays in `/var/lib/rex`; systemd's
`StateDirectory` ownership follows the service user, preserving the enrolled
Tailscale identity when switching from the default `rex` account.

Changing the service user restarts Rex and ends existing terminals. Check for
active work before deployment; existing terminals cannot change users in place.

Apply the server setting with an authorized `hey nuc` deployment. Apply the Mac
config with an authorized `hey re`, then `rex config reload`. Verify with
`rex hosts check nuc --json` and `rex -S nuc whoami --json`. A CLI connection
alone does not prove the app connected; `rex -S nuc client ls --json` must also
show the Mac app connected. Select a session listed by `rex -S nuc ls --json`
through that remote app client, then verify its session attachment. In a new
terminal, `whoami` and `pwd` should report `emiller` and `/home/emiller`.

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

## Agent status

Claude Code and Codex report state to Rex through the
[Program Status Protocol](https://www.superlogical.com/rex/docs/build/program-status)
(OSC 7501). `hooks/agent-status.sh` finds the pane's tty (hooks have no
controlling terminal) and emits `working`, `blocked`, `done`, or `clear`. It is
a no-op outside Rex. Activation (`rexAgentStatusHooks`) merges the hooks into
`~/.claude/settings.json` and `~/.codex/hooks.json`, keeping existing hooks.
`env.zsh` sets `CLAUDE_CODE_DISABLE_TERMINAL_TITLE=1` inside Rex so tabs show
Rex's own names instead of Claude's long title. Restart agent sessions after
activation. Check with `rex api call --session "$REX_SESSION"
com.superlogical.terminal.program_status`.

## Shortcuts

| Keys                                   | Action                              |
| -------------------------------------- | ----------------------------------- |
| `Ctrl+C`, then `Ctrl+C`                | Send an interrupt to the terminal   |
| Prefix + `c`, `n`, `p`                 | New, next, previous tab             |
| Prefix + `s`, `v`                      | Split below, right                  |
| Prefix + `f`, `Shift+F`                | Fork Pi into a right split, new tab |
| Prefix + `h/j/k/l`                     | Focus left/down/up/right            |
| Prefix + `x`, `z`                      | Close pane/tab/window, toggle zoom  |
| Prefix + `w`, `b`                      | Switch session, toggle sidebar      |
| `Ctrl+Shift+H/J/K/L`                   | Resize by 10                        |
| Prefix + `r`                           | Enter resize mode                   |
| Resize mode `h/j/k/l`, `Shift+H/J/K/L` | Resize, resize by 15                |
| Resize mode `=`, `Enter` or `Escape`   | Balance panes, leave mode           |

Bare `Ctrl+H/J/K/L` pass through to terminal applications. Other Rex shortcuts
keep their client defaults, including the `Cmd+Shift+P` command palette.

The fork bindings require the `pi-rex` extension in the focused Pi session.
They send `Ctrl+Alt+F` and `Ctrl+Alt+T` to Pi without replacing its editor draft.
The fork contains the selected conversation branch, opens in the same working
directory, and gets focus. Wait for Pi to finish its current turn first.
These keys are not shell commands; use them only while Pi is in the foreground.
See [pi-rex](../../packages/pi-packages/pi-rex/README.md#fork-into-a-split-or-tab).

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
