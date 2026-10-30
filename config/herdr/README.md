---
purpose: Explain native Herdr deployment and retained legacy workflows.
applies_to: People changing or operating either Herdr backend.
entrypoint: Check modules.shell.herdr.backend, then read the matching section.
verification: Native behavior tests and mod checks; legacy TOML checks.
update_when: Backend ownership, commands, preferences, or workflows change.
---

# Herdr

## Native app

Both platforms default to `modules.shell.herdr.backend = "native"`.
`modules.shell.herdr.native.app.enable` defaults to `true` on Macs and `false`
on Linux servers, including the NUC. Macs receive app preferences, personal
mods and `herdr-dev`. Servers only select the native CLI backend and
check for `hc`; they receive no app files, app helpers or legacy integrations.
Set `native.app.enable = true` explicitly for a Linux desktop, or `false` for
a headless Mac. Writable app state and running sessions are left untouched.

The native app and its persistent core are separate programs, `herdr-app` and
`hc`. The official installer owns their binaries and the signed app bundle.
Nix activation reports missing binaries but never downloads them. Bootstrap
a Mac with:

```sh
curl -fsSL https://releases.herdr.dev/app/install.sh | sh
```

Bootstrap a server with the core-only installer:

```sh
curl -fsSL https://releases.herdr.dev/core/install.sh | sh
```

`native.coreCommand` selects the installer-owned executable, defaulting to
`~/.local/bin/hc`. Update it with `hc update`; this preserves running terminals.

Nix does not patch or re-sign that bundle. The old Ghostty copy now lives at
`packages/herdr-ghostty` and has the separate name `Herdr Ghostty.app`.
Ghostty opens a plain shell when using native Herdr.

`native/settings.json`, `native/keys.json` and `native/programs.json` own only
the preferences they contain. Activation deep-merges those values into writable
files under `~/.config/herdr-app`, preserves other preferences, and refuses
invalid JSON instead of resetting it. It sets `core` to the declared native
core executable. Sounds default off. Fonts, themes, zoom and default navigation
stay with the app and the user's choices. Native Herdr owns its palette; it
cannot inherit Ghostty's `terminal` theme.

Cmd+Shift+G or Ctrl+Shift+G opens the personal Dev tools mod. Existing app
shortcuts remain, including Cmd+T, Cmd+D and Cmd+Shift+P on macOS. Ctrl+C goes
to the program; the old Ctrl+C prefix mode is not installed.

```sh
herdr-dev open /path/to/checkout --agent pi
herdr-dev open /path/to/checkout --agent omp
herdr-dev hunk
herdr-dev hunk --staged
herdr-dev hunk --branch origin/main
```

`open` validates an existing Git checkout, runs its executable
`scripts/qmd-seed-worktree.sh` if present, then creates an agent space and a
Hunk tab. The default agent is OMP, matching the old Workspace Manager layout.
Hunk reviews the invoking directory beside the focused local terminal pane.
The panel uses the focused pane's directory. Remote and composition panes are
rejected. Failures report partial resources and never close or delete them.

Pi 1.3.0 reports OSC 7501 status natively. Legacy socket-based integrations,
pi-herdr review boxes and internal URLs are not enabled in native mode. Other
agents must report OSC 7501 to appear as agents; their legacy integrations are
not evidence of native protocol support.

`hnuc` opens a native remote shell; `hnuc t7` attaches an existing terminal.
Mac app hosts declare `native.machines.nuc = "emiller@nuc"` by default, using
the existing `nuc` SSH alias over Tailscale. Activation registers missing
machines through `hc` after SSH configuration is linked. The app reads that
same default core session; no separate app connection is needed.

Registration preserves other machines and running sessions. It refuses a
conflicting name instead of removing/replacing a connection. Offline or failed
registration warns and retries on the next activation, without blocking a Mac
rebuild or installing anything on the server. Set `native.machines = { };` to
disable registration; removing a declaration does not delete a saved machine.
Servers and headless Macs default to no outbound machine registrations.

Native `herdr-studios sync` uses `hc machine add --install` with stable SSH
alias names. It preserves
existing registered machines, including stopped or filtered Studios; it does
not translate the old enable/disable lifecycle into deletion.

### Compatibility limits

The legacy plugin ecosystem is retained, not converted to mods. Projects,
Vercel Sandbox, safe jj creation/removal, smart rename, timelines and old review
boxes remain legacy-only. Their options are inactive under the native backend.
Use `backend = "legacy"` when those capabilities are required. CLI tools such
as Hunk remain usable independently. No backend switch migrates or deletes
sessions, worktrees, machine profiles or old configuration.

Native recovery starts a shell after a lost terminal. It never reruns the
original agent task. App commands own spaces, tabs and splits; the old YAML
is not a native layout file. Shipped layouts/mods, generated instructions and
typings, click state and runtime documents remain app-owned.

### Checks and application

```sh
uv run --with pytest python -m pytest -q tests/test_herdr_native_config.py \
  tests/test_herdr_native_dev.py tests/test_herdr_studios_native.py
herdr-app check config/herdr/native/mods/dotfiles-dev
hey check config/herdr modules/shell/herdr
```

Source checks do not activate preferences or install the panel. An authorized
`hey re` applies the selected backend. Native JSON and mods reload live; no
`herdr server reload-config` or core restart is needed. Never stop the old
server to apply the new app configuration.

## Legacy TUI backend

Everything below applies only to `backend = "legacy"`. Its configuration,
plugins and writable activation remain available without modifying native
Herdr. The old terminal multiplexer reads config from:

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
- let activation read managed keys, commands, theme, UI, session, experimental,
  and worktree values from that selected template
- keep only host-specific additions and plugin lifecycle in Nix
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
| `prefix+shift+1..9`               | Switch workspace                                   |
| `prefix+alt+1..9`                 | Focus agent                                        |
| `prefix+J` / `prefix+K`           | Next/previous agent                                |
| `prefix+shift+left/right`         | Move tab                                           |
| `prefix+X`                        | Close tab                                          |
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
| `prefix+a`                        | New jj workspace                                   |
| `prefix+d`                        | Remove clean closed-PR jj workspace                |
| `prefix+D`                        | Abandon clean jj workspace with typed confirmation |
| `prefix+t`                        | Smart rename current agent tab                     |
| `prefix+T`                        | Agent timeline                                     |
| `prefix+R`                        | Refresh GitHub PR status                           |
| `prefix+P`                        | Open issue or PR in Ghzinga                        |
| `prefix+M`                        | Open cliamp player (cliamp-enabled hosts)          |
| `prefix+I`                        | Start GitHub issue workflow                        |
| `prefix+O`                        | Start from GitHub item                             |
| `prefix+B`                        | Open Herdr Browser in a right split                |

Herdr defaults still provide other common actions. `prefix+a` creates a task-named jj workspace; `prefix+g` is the native Git fallback. Both receive the declarative `dev` layout from `workspace-manager.yml`: `$AGENT` first, then Hunk. Ordinary workspaces stay plain.

Export `AGENT` as the executable name or path in the pane's shell environment,
without arguments. The agent pane runs `exec "$AGENT"`; an unset or empty
value reports an error rather than falling back to OMP. Use an executable
wrapper if the selected agent needs startup arguments.

With jj 0.46 or newer, `prefix+a` creates a colocated child with its own Git
worktree when the source workspace is colocated and `git.colocate` is true,
its default. Hunk can review that child directly. There is no separate Git
worktree creation or jj initialization step. Keep VCS mutations in jj and
publish the explicit task bookmark.

Existing non-colocated jj children do not convert automatically. From the
child, confirm `jj root --ignore-working-copy`, inspect `pwd` and `jj log -r @`,
then use `jj git colocation enable` to convert it in place. Before opening Hunk,
confirm `git rev-parse --show-toplevel` resolves to the same child checkout.
For children kept non-colocated, review with `jj diff --git -r @` in the agent pane;
the `dev` layout does not omit the Hunk tab automatically. Never initialize jj
inside a Git-only worktree to imitate this conversion.

Keep `prefix+d` and `prefix+D` for guarded cleanup. The plugin's
`jj workspace forget` unregisters the child's Git worktree before directory
removal. Colocation does not replace the clean-workspace, closed-PR, typed
abandonment, or primary-workspace protections.

Herdr-launched agents also inherit the Nix-packaged `rift` CLI for experimental copy-on-write workspace trials. Rift is not bound to a key and does not replace native Git or jj workspace lifecycle.

Native session context is intentionally compact: visible tab rows show zoom state
and hostname, while the host terminal title uses `{hostname}: {workspace}`.
Herdr owns both directly; no window-title plugin is installed. The `terminal`
theme inherits every color from the active terminal palette on every host.

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

- Workspace Manager applies `workspace-manager.yml` automatically to linked Git worktrees under `~/.local/share/herdr/worktrees`.
- The patched jj workspace plugin applies the same named layout explicitly after creating its generic Herdr workspace. Keep this integration for colocated children too; a backing Git worktree does not make the plugin emit Herdr's native `worktree.created` event.
- `worktree.opened` would fit rehydrating plugin-owned state when an existing checkout opens. No separate hook is needed now because layout state persists and a newly opened workspace emits `workspace.created`.
- `worktree.removed` would fit deleting plugin-owned per-checkout cache. Do not use it to replace the explicit safe removal in the `done` skill; no such cache exists today.
- Smart rename should remain on `workspace.created` and `tab.created`; it is workspace/tab lifecycle, not Git checkout lifecycle.

Inspect the version-matched event schema with `herdr api schema --json`. Event
hooks receive `HERDR_PLUGIN_EVENT`, `HERDR_PLUGIN_EVENT_JSON`, and
`HERDR_PLUGIN_CONTEXT_JSON`.

## Plugins

Repo-owned plugins are composed into a local package and registered by `modules/shell/herdr/default.nix`:

- `dotfiles.agent-read-command` — copies a `herdr agent read ...` command from pane/tab context menus.
- `dotfiles.github-link-preview` — opens GitHub issue/PR previews in a Herdr side pane.
- `nathanflurry.jj-workspace` — built from a pinned upstream revision plus lifecycle-safety and Workspace Manager integration patches under `packages/herdr-plugin-jj-workspace/`.
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
- `wyattjoh/herdr-plugin-gh-pr`
- `kkckkc/herdr-plugin-gh-workflow`
- `alon-z/herdr-command-palette`
- `0x5c0f/herdr-insight`
- `ChmaraX/herdr-nvim`
- `plannotator/herdr-annotate`
- `nicosuave/memex`
- `jhochenbaum/herdr-hunk-diff`
- `thanhdat77/herdr-navigator`
- `persiyanov/herdr-reviewr`
- `coryshaw1/herdr-cliamp` when `modules.shell.cliamp` is enabled
- `eliasstravik/herdr-projects` when `modules.shell.herdr.projects.enable` is
  true, pinned to `a4cdb0a69713d982d96f9062548cf885f013c442` via
  `herdr plugin install --ref`. The plugin builds itself with
  `cargo build --release --locked` (Rust 1.89+) and requires Herdr 0.9.1+.
  This flake packages Herdr 0.9.1. Activation still treats a GitHub
  access miss as optional and continues. GitHub currently serves the repo
  as public, but the plugin README still says private access may be
  required.

Private GitHub plugins use the active `gh` login through a transient,
`github.com`-scoped Git credential helper. Activation passes that helper only
to `herdr plugin install`; it does not copy a token into Nix, export one to the
rest of activation, or modify the user's Git config. Verify or recover the
credential with `gh auth status --hostname github.com` or `gh auth login
--hostname github.com`.

`kryptamine/herdr-auto-title` is intentionally excluded: it requires Herdr
0.8.2 or newer and duplicates the managed OMP-backed smart-rename worker.

Workspace Manager reads the Nix-managed `config/herdr/workspace-manager.yml`.
Its path matcher covers native Herdr worktrees but not Review Boxes under
`/.pi/worktrees/`; the Review Box launcher therefore remains the sole owner of
its Hunk, Critique, agent, and approval tabs.

MacTraitor Pro and Seqeratop also enable `eliasstravik/herdr-projects`. After
a successful install, create the first project from Herdr's action menu
(**Projects: new project**) or:

```bash
herdr-projects new "Billing" --repo ~/dev/app
herdr-projects open billing
```

Check the plugin with `herdr plugin action invoke doctor --plugin herdr-projects`.
After rebuilding onto Herdr 0.9.1, restart the running server if
`herdr status` reports `server_binary_stale`; plugins that require 0.9.1
need both the new CLI and the new server. If GitHub returns 404, run
`gh auth login --hostname github.com` so the marketplace helper can clone
the repo, then rebuild. A host without rustup 1.89+ can still fail the
first Cargo build; activation prefers `~/.cargo/bin` over Nix rustc.

MacTraitor Pro additionally enables `vercel-labs/herdr-vercel-sandbox-plugin`.
Its managed config selects Codex in a Node 24 Sandbox. Use `prefix+S` to start,
`prefix+A` to apply remote changes, `prefix+C` to reconnect, `prefix+Q` to stop
compute, and `prefix+E` to inspect the pane-to-Sandbox mapping. The focused Git
worktree must be linked with `vercel link`; Vercel and Codex authentication stay
in their official interactive flows and are never copied from host credentials.

The smart-rename worker starts idempotently during activation and on `workspace.created` or `tab.created`. `prefix+t` remains the explicit current-tab override.

## Seqera Studios as machines

`herdr-studios sync` lists your SSH-enabled Studios across every Seqera Platform
workspace, writes a `seqera-studio-a<sessionId>` Host alias for each to
`~/.ssh/seqera-studios.conf` (included from `~/.ssh/config`), and runs
`herdr machine add` for running ones. Because `machine add` only installs the
remote server after an interactive approval, sync first downloads the matching
Herdr release binary to `~/.local/bin/herdr` on the Studio, and it retries the
add, which intermittently fails with ssh exit 255 over the Connect proxy. On later runs it enables saved Studios that
are running again, disables stopped ones, and removes deleted ones. It only
touches machines whose target starts with `seqera-studio-`.

`herdr-studios list [--include-stopped]` shows what it would manage. Pass
`--all-users` to include Studios owned by others, and `--dry-run` to sync without
writing anything. The token comes from `TOWER_ACCESS_TOKEN` or
`SEQERA_ACCESS_TOKEN`, falling back to 1Password. Herdr's background connections
cannot answer prompts, so approve the 1Password SSH key with a plain
`ssh seqera-studio-a<id> true` if `machine add` reports an auth failure.

## Reloading after edits

After editing the live config or applying a rebuild, reload the running Herdr server:

```bash
herdr server reload-config
```

A successful reload returns `status: applied`.

## Notes

Do not bind actions to plain printable keys such as `w`, `s`, `p`, or `n`; Herdr 0.6 disables those unsafe direct bindings because they intercept normal typing. Use `prefix+...` bindings, and avoid key sequences already claimed by Herdr defaults unless you intentionally want to replace them.
