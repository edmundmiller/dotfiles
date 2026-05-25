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

## Current keybinding conventions

Current preferred keys:

```toml
[keys]
prefix = "ctrl+c"
new_workspace = "prefix+w"
new_worktree = "prefix+g"
open_worktree = "prefix+G"
workspace_picker = "prefix+O"
split_horizontal = "prefix+-"
# Intercept hard-coded navigate q quit/detach with a harmless action.
toggle_sidebar = "prefix+b"
previous_tab = "prefix+p"
next_tab = "prefix+n"

[[keys.command]]
key = "prefix+alt+g"
command = "herdr-worktree-layout"

[[keys.command]]
key = "prefix+ctrl+g"
command = "herdr-worktree-layout"

[[keys.command]]
key = "prefix+["
command = "herdr-hunk"

[[keys.command]]
key = "prefix+]"
command = "herdr-hunk --tab"
```

Meaning:

- `prefix+w` creates a workspace.
- `prefix+g` creates a worktree with Herdr's native prompt.
- `prefix+alt+g` / `prefix+ctrl+g` creates a native worktree via socket API and opens Pi + Hunk + Neovim tabs.
- `prefix+G` opens an existing worktree.
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
- Keep `prefix+ctrl+g` as a fallback for `herdr-worktree-layout`: `prefix+alt+g` was present in config but did nothing after reload, likely because Alt was swallowed by the macOS terminal/tmux stack.
- Use `type = "pane"` for `herdr-worktree-layout`, not `type = "shell"`: the script prompts for a branch name, and shell commands run detached with no interactive stdin so they appear to do nothing.
- `bin/herdr-workspace` was experimental and is not part of the active keymap unless deliberately reintroduced.

## Related files

- `modules/shell/herdr/default.nix` bootstraps and upserts selected live config keys.
- `bin/herdr-tab` remains available for experiments; active tab movement uses Herdr built-ins.
- `bin/herdr-hunk` implements Hunk split/tab launch behavior.
- `bin/herdr-worktree-layout` implements the layout-seeded native worktree flow.
- `packages/herdr/AGENTS.md` covers Nix packaging of the upstream Herdr binary, not runtime keybindings.
