# jmux

Nix package for upstream `jarredkenny/jmux` with a tiny local patch.

## Purpose

Provides a wrapped `jmux` binary that uses `C-c` as the effective prefix in this dotfiles setup, matching the tmux config in `config/tmux/config`.

## Local delta

- Patches `src/input-router.ts` so jmux's UI intercept layer reads the prefix from `JMUX_PREFIX_KEY` instead of hardcoding `Ctrl-a`.
- Patches the new-session/worktree shortcut so it reads `JMUX_NEW_SESSION_KEY` and defaults to `Shift+M`, leaving `prefix+n` available for tmux `next-window` again.
- Wrapper sets `JMUX_PREFIX_KEY=C-c` and `JMUX_NEW_SESSION_KEY=M` by default.
- Wrapper prefixes `tmux` and `git` into `PATH`.

## Why this exists

Upstream jmux lets tmux itself override the prefix via `~/.tmux.conf`, but its UI interception code was still hardcoded to `Ctrl-a`. That made `prefix+n`, `prefix+p`, settings, and diff-panel shortcuts inconsistent when tmux prefix was `C-c`. This package also moves jmux's new-session/worktree intercept off lowercase `n` so `prefix+n` stays tmux `next-window`, matching the rest of this setup.

## Validation

```bash
nix build .#jmux
./result/bin/jmux --help
```

After rebuild, Ghostty/open-jmux should launch this packaged jmux because `modules.shell.tmux.jmux.package` points at `pkgs.my.jmux`.
