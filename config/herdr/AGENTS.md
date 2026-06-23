# Herdr Config

Tracked Herdr runtime config lives here and is wired in by `modules/shell/herdr/default.nix`.

## Source of truth

- Edit `config/herdr/config.toml` for user-facing Herdr keybindings/settings.
- The shell module defaults `modules.shell.herdr.configFile` to this tracked file.
- The live file is `~/.config/herdr/config.toml`, but it is intentionally writable because Herdr writes some settings itself.
- Do **not** add `onboarding = false` to the tracked config. Let Herdr manage onboarding/settings state.

After edits, update the live config if needed and reload:

```bash
herdr server reload-config
```

To inspect upstream/default keybindings for the currently installed Herdr:

```bash
herdr --default-config
# Or just the keys section:
herdr --default-config | sed -n '/^\[keys\]/,/^\[/p'
```

## Current keybinding conventions

Current preferred keys:

```toml
[keys]
prefix = "ctrl+c"
new_workspace = "prefix+w"
new_worktree = "prefix+g"
goto = "prefix+f"
open_worktree = "prefix+G"
workspace_picker = "prefix+O"
split_horizontal = "prefix+-"
# Intercept hard-coded navigate q quit/detach with a harmless action.
toggle_sidebar = "prefix+b"
previous_tab = "prefix+p"
next_tab = "prefix+n"

[[keys.command]]
key = "prefix+u"
type = "plugin_action"
command = "dotfiles.dev-layout.hunk-split"

[[keys.command]]
key = "prefix+U"
type = "plugin_action"
command = "dotfiles.dev-layout.hunk-tab"

[[keys.command]]
key = "prefix+a"
type = "plugin_action"
command = "nathanflurry.jj-workspace.new"

[[keys.command]]
key = "prefix+A"
type = "plugin_action"
command = "nathanflurry.jj-workspace.new-tab"

[[keys.command]]
key = "prefix+d"
type = "plugin_action"
command = "nathanflurry.jj-workspace.remove"
```

Meaning:

- `prefix+w` creates a workspace.
- `prefix+g` creates a worktree with Herdr's native prompt; the `dotfiles.dev-layout` plugin handles Herdr's `worktree.created` event and opens Pi + Hunk + Neovim + shell tabs.
- `prefix+G` opens an existing worktree.
- `prefix+f` opens Herdr goto/navigation.
- `prefix+-` splits horizontally.
- `prefix+b` toggles the sidebar.
- `prefix+p` / `prefix+n` move to previous/next tab via Herdr built-ins.
- `prefix+u` opens Hunk in a focused split.
- `prefix+U` opens Hunk in a new tab.
- `prefix+a` creates a jj workspace as a new Herdr workspace.
- `prefix+A` creates a jj workspace as a tab.
- `prefix+d` removes the current jj workspace.

## Important gotchas

- Use explicit `prefix+...` bindings. Plain printable direct bindings steal input from shells/editors.
- Marketplace/GitHub plugins are installed by `modules/shell/herdr/default.nix`; do not add keybindings for new marketplace plugins until their installed action IDs have been verified with `herdr plugin action list`.
- Keep `toggle_sidebar` bound unless Herdr adds a real way to disable navigate-mode `q`; configured actions are handled before reserved keys.
- `H`/`L` should remain available for pane/window navigation, not workspace movement.
- Attempts to bind workspace navigation to `(`/`)`, `shift+9`/`shift+0`, and `shift+(`/`shift+)` were unreliable in this terminal/Herdr stack.
- Keep worktree layout seeding in the local `dotfiles.dev-layout` plugin's `worktree.created` event hook; do not reintroduce custom prompt keybindings, AppleScript dialogs, or dotfiles-only Herdr CLI patches for this flow.
- `herdr workspace` was experimental and is not part of the active keymap unless deliberately reintroduced.

## Related files

- `modules/shell/herdr/default.nix` bootstraps and upserts selected live config keys.
- `config/herdr/plugins/dotfiles-dev-layout/` implements Hunk split/tab actions and native worktree post-create tab seeding as a Herdr plugin.
- `config/herdr/plugins/dotfiles-github-link-preview/` implements Ctrl-click GitHub issue/PR previews as a Herdr link-handler plugin.
- Marketplace/GitHub plugins installed by activation: `NathanFlurry/herdr-plugin-jj-workspace`, `smarzban/herdr-file-viewer`, `dutifuldev/ghzinga/plugins/herdr`, `dcolinmorgan/herdr-remote/relay`, `razajamil/herdr-plugin-workspace-manager`, `paulbkim-dev/vim-herdr-navigation`, `ogulcancelik/herdr-plugin-github-start`, `rjyo/herdr-window-title-sync`, `wyattjoh/herdr-plugin-gh-pr`, `kkckkc/herdr-plugin-gh-workflow`, `alon-z/herdr-command-palette`, and `0x5c0f/herdr-insight`.
- `overlays/herdr/default.nix` patches only packaging/build issues; local helper behavior should live in Herdr plugins, not inside the Herdr binary.
