---
purpose: Route Herdr config, plugin, keybinding, and runtime verification changes.
applies_to: Changes under config/herdr or modules/shell/herdr.
entrypoint: Edit config/herdr/config.toml and the owning plugin or module source.
verification: Run focused plugin tests, rebuild, then reload and inspect Herdr state.
update_when: Herdr bindings, plugin ownership, lifecycle, or recovery changes.
---

# Herdr Config

Tracked Herdr runtime config lives here and is wired in by `modules/shell/herdr/default.nix`.

## Source of truth

- Edit `config/herdr/config.toml` for user-facing Herdr keybindings/settings.
- The shell module defaults `modules.shell.herdr.configFile` to this tracked file.
- Activation parses that selected template and reapplies its managed sections;
  do not duplicate their values in the Nix activation script.
- The live file is `~/.config/herdr/config.toml`, but it is intentionally writable because Herdr writes some settings itself.
- Do **not** add `onboarding = false` to the tracked config. Let Herdr manage onboarding/settings state.
- Do **not** restore `[worktrees].post_create_command`. Use packaged plugin event hooks.

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

## Current visual conventions

- Hide pane scrollbars and gaps to keep split layouts compact.
- Hide outer pane borders while retaining separators between splits.
- Hide the tab row when a workspace has one tab.
- Show zoom state and hostname at the right of a visible tab row.
- Set the host terminal title to `{hostname}: {workspace}` with Herdr's native template.
- Create tabs immediately with generated names; use smart rename when needed.

## Current keybinding conventions

Current preferred keys:

```toml
[keys]
prefix = "ctrl+space"
settings = "prefix+comma"
reload_config = "prefix+ctrl+r"
workspace_picker = "prefix+w"
new_workspace = "prefix+N"
new_worktree = "prefix+g"
goto = "prefix+/"
open_worktree = "prefix+G"
new_tab = "prefix+c"
rename_tab = "prefix+alt+t"
switch_tab = "prefix+1..9"
previous_tab = "prefix+p"
next_tab = "prefix+n"
focus_pane_left = "prefix+h"
focus_pane_down = "prefix+j"
focus_pane_up = "prefix+k"
focus_pane_right = "prefix+l"
last_pane = "prefix+ctrl+w"
cycle_pane_next = "prefix+tab"
cycle_pane_previous = "prefix+shift+tab"
split_horizontal = "prefix+s"
split_vertical = "prefix+v"
close_pane = "prefix+x"
zoom = "prefix+z"
resize_mode = "prefix+r"
edit_scrollback = "prefix+enter"
# Intercept hard-coded navigate q quit/detach with a harmless action.
toggle_sidebar = "prefix+b"

[[keys.command]]
key = "prefix+m"
type = "plugin_action"
command = "alonz.command-palette.open"

[[keys.command]]
key = "prefix+space"
type = "plugin_action"
command = "edmundmiller.which-key.open"

[[keys.command]]
key = "prefix+f"
type = "plugin_action"
command = "herdr-file-viewer.open-file-viewer"

[[keys.command]]
key = "prefix+F"
type = "plugin_action"
command = "herdr-file-viewer.open-file-viewer-tab"

[[keys.command]]
key = "prefix+]"
type = "plugin_action"
command = "hunk.diff.worktree-split"

[[keys.command]]
key = "prefix+}"
type = "plugin_action"
command = "hunk.diff.staged-split"

[[keys.command]]
key = "prefix+{"
type = "plugin_action"
command = "hunk.diff.branch-split"

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
key = "prefix+d"
type = "plugin_action"
command = "nathanflurry.jj-workspace.remove"

[[keys.command]]
key = "prefix+D"
type = "plugin_action"
command = "nathanflurry.jj-workspace.abandon"

[[keys.command]]
key = "prefix+t"
type = "plugin_action"
command = "tab-smart-rename.rename-now"

[[keys.command]]
key = "prefix+T"
type = "plugin_action"
command = "herdr-insight.open-timeline-right"

[[keys.command]]
key = "prefix+R"
type = "plugin_action"
command = "gh-pr.refresh"

[[keys.command]]
key = "prefix+I"
type = "plugin_action"
command = "kkckkchosts.herdr-plugin-gh-workflow.gh-issue-develop"

[[keys.command]]
key = "prefix+O"
type = "plugin_action"
command = "ogulcancelik.github-start.open"

[[keys.command]]
key = "prefix+B"
type = "shell"
command = "${HERDR_BIN_PATH} plugin pane open --plugin official.browser --entrypoint browser --placement split --direction right --focus"
```

Meaning:

- `prefix+w` opens the workspace picker.
- `prefix+N` creates a workspace.
- `prefix+g` creates a native Git worktree. Creation bootstraps OMP and, only inside a Git checkout, Hunk; OMP is focused.
- `prefix+G` opens an existing worktree.
- `prefix+/` opens Herdr goto/navigation.
- `prefix+c` creates a tab.
- `prefix+alt+t` renames a tab.
- `prefix+1..9` switches tabs.
- `prefix+h/j/k/l` moves focus between panes.
- `prefix+s` / `prefix+v` split panes.
- `prefix+x` closes a pane.
- `prefix+z` zooms a pane.
- `prefix+r` enters resize mode.
- `prefix+comma` opens settings.
- `prefix+ctrl+r` reloads config.
- `prefix+b` toggles the sidebar.
- `prefix+p` / `prefix+n` move to previous/next tab via Herdr built-ins.
- `prefix+m` opens the command palette.
- `prefix+space` opens which-key.
- `prefix+f` / `prefix+F` open the file viewer in a split/tab.
- `prefix+]` / `prefix+}` / `prefix+{` open Hunk worktree/staged/branch diffs.
- `prefix+u` / `prefix+U` keep the dotfiles dev-layout Hunk split/tab actions.
- `prefix+a` creates a stable task-named jj workspace as a new Herdr workspace.
- `prefix+d` removes a clean jj workspace only after its PR closes or merges.
- `prefix+D` abandons a clean jj workspace after exact typed task-name confirmation.
- `prefix+t` smart-renames the current agent tab from its task context.
- `prefix+T` opens the agent timeline.
- `prefix+R` refreshes GitHub PR status.
- `prefix+I` starts the GitHub issue workflow.
- `prefix+O` starts from a GitHub item.
- `prefix+B` opens Herdr Browser in a right split.

## Important gotchas

- Use explicit `prefix+...` bindings. Plain printable direct bindings steal input from shells/editors.
- Marketplace/GitHub plugins are installed by `modules/shell/herdr/default.nix`; repo-owned patched plugins are packaged under `packages/`. Do not add keybindings until their installed action IDs have been verified with `herdr plugin action list`.
- Keep `toggle_sidebar` bound unless Herdr adds a real way to disable navigate-mode `q`; configured actions are handled before reserved keys.
- `H`/`L` should remain available for pane/window navigation, not workspace movement.
- Attempts to bind workspace navigation to `(`/`)`, `shift+9`/`shift+0`, and `shift+(`/`shift+)` were unreliable in this terminal/Herdr stack.
- Keep checkout layout seeding in the local `dotfiles.dev-layout` plugin's `workspace.created` and `worktree.created` hooks. The bootstrap serializes per workspace, is idempotent, and opens Hunk only from a Git checkout.
- `herdr workspace` was experimental and is not part of the active keymap unless deliberately reintroduced.

## Related files

- `modules/shell/herdr/default.nix` bootstraps and upserts selected live config keys.
- `packages/herdr-plugins/dotfiles-dev-layout/` implements Hunk split/tab actions and the OMP/Hunk checkout bootstrap.
- `packages/herdr-plugins/dotfiles-github-link-preview/` implements Ctrl-click GitHub issue/PR previews.
- `packages/herdr-plugin-jj-workspace/` owns the pinned upstream source and local lifecycle-safety patch.
- `packages/herdr-tab-smart-rename/` owns the pinned upstream source, OMP provider patch, and automatic worker lifecycle.
- `ogulcancelik/herdr-browser` is installed from GitHub; it requires `[experimental].kitty_graphics = true`.
- Other marketplace plugins are installed by `modules/shell/herdr/default.nix`.
- `overlays/herdr/default.nix` patches only packaging/build issues; local helper behavior should live in Herdr plugins, not inside the Herdr binary.
