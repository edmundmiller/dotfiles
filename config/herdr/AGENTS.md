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
key = "prefix+["
command = "herdr hunk"

[[keys.command]]
key = "prefix+]"
command = "herdr hunk --tab"
```

Meaning:

- `prefix+w` creates a workspace.
- `prefix+g` creates a worktree with Herdr's native prompt, then `worktrees.post_create_command` opens Pi + Hunk + Neovim + shell tabs.
- `prefix+G` opens an existing worktree.
- `prefix+f` opens Herdr goto/navigation.
- `prefix+-` splits horizontally.
- `prefix+b` toggles the sidebar.
- `prefix+p` / `prefix+n` move to previous/next tab via Herdr built-ins.
- `prefix+[` opens Hunk in a focused split.
- `prefix+]` opens Hunk in a new tab.

## Important gotchas

- Use explicit `prefix+...` bindings. Plain printable direct bindings steal input from shells/editors.
- Keep `toggle_sidebar` bound unless Herdr adds a real way to disable navigate-mode `q`; configured actions are handled before reserved keys.
- `H`/`L` should remain available for pane/window navigation, not workspace movement.
- Attempts to bind workspace navigation to `(`/`)`, `shift+9`/`shift+0`, and `shift+(`/`shift+)` were unreliable in this terminal/Herdr stack.
- Keep worktree layout seeding on `[worktrees].post_create_command`; do not reintroduce custom prompt keybindings or AppleScript dialogs.
- `herdr workspace` was experimental and is not part of the active keymap unless deliberately reintroduced.

## Related files

- `modules/shell/herdr/default.nix` bootstraps and upserts selected live config keys.
- `herdr hunk` implements Hunk split/tab launch behavior.
- `herdr worktree layout` implements post-create tab seeding for the native worktree flow.
- `overlays/herdr/default.nix` patches upstream Herdr; local helper behavior lives inside the Herdr binary.
