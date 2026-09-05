# Tmux integration

The wrapper supplies `TMUX_HOME`, `DOTFILES`, and `DOTFILES_BIN` fallbacks for
GUI launches without shell profiles and forces `-f "$TMUX_HOME/config"`.
Load the theme before prefix-highlight so its placeholder can be replaced.
Actual bindings/scripts live under `config/tmux/`.

## Optional integrations

- Opensessions uses a mutable upstream checkout at
  `~/.local/share/opensessions/current` and a one-time runtime config seed.
  `config/opensessions/plugins/hunk.js` is linked as its Hunk watcher.
  Native `prefix o` and which-key's `prefix Space o` remain available.
- Jmux reads `~/.config/jmux/config.json`, not KDL. Generated launchers and a
  compatibility `~/.tmux.conf` shim preserve XDG tmux config. `pkgs.my.jmux`
  aligns its prefix to `C-c` and new-session/worktree action to `prefix M`,
  reserving `prefix n` for tmux next-window. Keep `unbind M` after plugin load.
  The generated zsh alias also selects that packaged binary.

## Sesh

Popup shells may have minimal PATH. Preserve `SESH_BIN`/`FZF_TMUX_BIN` resolver
fallbacks in `sesh-picker.sh` and `sesh-all.sh`, not Homebrew-only paths.
`zoxide-list.sh` drops `/.git` entries and missing directories, and calls
`git-worktree-cwd` only for bare-hub candidates (HEAD exists, .git absent).
Focused regressions are in `config/tmux/tests/sesh.zunit`.
