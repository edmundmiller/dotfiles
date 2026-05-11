# Herdr Config

Tracked Herdr runtime config lives here and is wired in by `modules/shell/herdr.nix`.

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
new_workspace = "w"
split_horizontal = "s"

[[keys.command]]
key = "p"
command = "herdr-tab previous"

[[keys.command]]
key = "n"
command = "herdr-tab next"

[[keys.command]]
key = "["
command = "herdr-hunk"

[[keys.command]]
key = "]"
command = "herdr-hunk --tab"
```

Meaning:

- `prefix+w` creates a workspace.
- `prefix+s` splits horizontally.
- `prefix+p` / `prefix+n` move to previous/next tab via `bin/herdr-tab`.
- `prefix+[` opens Hunk in a focused split.
- `prefix+]` opens Hunk in a new tab.

## Important gotchas

- Do **not** use Herdr's built-in `previous_tab` / `next_tab` for `p`/`n`. Those are terminal-direct as well as navigate-mode, so plain `p`/`n` gets stolen from shells/editors.
- Prefix-only tab navigation should remain implemented as `[[keys.command]]` entries calling `bin/herdr-tab`.
- `H`/`L` should remain available for pane/window navigation, not workspace movement.
- Attempts to bind workspace navigation to `(`/`)`, `shift+9`/`shift+0`, and `shift+(`/`shift+)` were unreliable in this terminal/Herdr stack.
- `bin/herdr-workspace` was experimental and is not part of the active keymap unless deliberately reintroduced.

## Related files

- `modules/shell/herdr.nix` bootstraps and upserts selected live config keys.
- `bin/herdr-tab` implements prefix-only tab previous/next.
- `bin/herdr-hunk` implements Hunk split/tab launch behavior.
- `packages/herdr/AGENTS.md` covers Nix packaging of the upstream Herdr binary, not runtime keybindings.
