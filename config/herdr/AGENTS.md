# Herdr configuration

`config.toml` owns settings/keybindings; `workspace-manager.yml` owns persistent
tab/pane topology. `modules/shell/herdr/default.nix` parses the selected template
and reapplies managed sections to writable `~/.config/herdr/config.toml`, leaving
Herdr-owned settings intact. Keep managed values in the template rather than
duplicating them in activation code.

- Let Herdr manage onboarding. Use packaged event hooks instead of
  `[worktrees].post_create_command`.
- Use explicit `prefix+...` bindings; printable direct bindings steal shell input.
  Confirm installed action IDs with `herdr plugin action list`.
- Retain `toggle_sidebar` to intercept navigate-mode `q`, and keep `H`/`L`
  available for pane/window navigation. Parenthesis workspace bindings have
  been unreliable in this terminal stack.
- Ghostty starts Herdr as the workspace owner; launcher fallbacks to tmux/jmux
  create a nesting loop.
- Native-worktree matching is scoped to `~/.local/share/herdr/worktrees` so
  Review Boxes under `/.pi/worktrees/` retain their launcher-owned layouts.
  Temporary tool panes may be created directly through Herdr.
- jj workspace removal requires a clean workspace and a closed/merged PR;
  abandonment requires exact typed task-name confirmation.

The template contains current visual conventions and bindings. Inspect upstream
defaults with `herdr --default-config`; reload applied config with
`herdr server reload-config` when live changes are authorized.

Marketplace installation belongs to the shell module; patched plugins belong
under `packages/`. `overlays/herdr/` owns packaging/build fixes, not dotfiles
helper behavior. Herdr Browser needs `experimental.kitty_graphics`; cliamp needs
`experimental.allow_nested` and `modules.shell.cliamp`.
