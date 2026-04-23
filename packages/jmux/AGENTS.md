# jmux

Nix package for upstream `jarredkenny/jmux` with a tiny local patch.

## Purpose

Provides a wrapped `jmux` binary that uses `C-c` as the effective prefix in this dotfiles setup, matching the tmux config in `config/tmux/config`.

## Local delta

- Patches `src/input-router.ts` so jmux's UI intercept layer reads the prefix from `JMUX_PREFIX_KEY` instead of hardcoding `Ctrl-a`.
- Wrapper sets `JMUX_PREFIX_KEY=C-c` by default.
- Wrapper prefixes `tmux` and `git` into `PATH`.

## Why this exists

Upstream jmux lets tmux itself override the prefix via `~/.tmux.conf`, but its UI interception code was still hardcoded to `Ctrl-a`. That made `prefix+n`, `prefix+p`, settings, and diff-panel shortcuts inconsistent when tmux prefix was `C-c`.

## Validation

```bash
nix build .#jmux
./result/bin/jmux --help
```

After rebuild, Ghostty/open-jmux should launch this packaged jmux because `modules.shell.tmux.jmux.package` points at `pkgs.my.jmux`.
