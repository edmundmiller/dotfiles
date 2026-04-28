# jmux

Nix package for upstream `jarredkenny/jmux` with a local patch stack.

## Purpose

Provides a wrapped `jmux` binary that uses `C-c` as the effective prefix in this dotfiles setup, matching the tmux config in `config/tmux/config`.

## Local delta

- Patch stack lives in `packages/jmux/patches/` and is intentionally split into focused patches:
  - configurable prefix/new-session key behavior
  - batched prefix-chunk handling (e.g. `C-cg` arriving in one input chunk)
  - help/welcome keybinding text updates
  - command-palette "Show Welcome" action
- Wrapper sets `JMUX_PREFIX_KEY=C-c` and `JMUX_NEW_SESSION_KEY=M` by default.
- Wrapper prefixes `tmux` and `git` into `PATH`.

## Maintenance rule

When changing jmux behavior, prefer adding/updating a small `.patch` file in `packages/jmux/patches/` over inline source mutation in `default.nix`.
Keep patch ordering stable and reflect it in the `patches = [ ... ]` list.

## Why this exists

Upstream jmux lets tmux itself override the prefix via `~/.tmux.conf`, but its UI interception code was still hardcoded to `Ctrl-a`. That made `prefix+n`, `prefix+p`, settings, and diff-panel shortcuts inconsistent when tmux prefix was `C-c`. This package also moves jmux's new-session/worktree intercept off lowercase `n` so `prefix+n` stays tmux `next-window`, matching the rest of this setup.

## Validation

```bash
nix build .#jmux
./result/bin/jmux --help
```

After rebuild, Ghostty/open-jmux should launch this packaged jmux because `modules.shell.tmux.jmux.package` points at `pkgs.my.jmux`.
