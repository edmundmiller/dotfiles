# Changelog

All notable changes to this repository are documented in this file.

## Unreleased

### Added
- Packaged upstream `jarredkenny/worktree-manager` as `pkgs.my.worktree-manager` and installed it on `mactraitorpro` for jmux bare-repo worktree flows.
- Packaged upstream `jarredkenny/jmux` as `pkgs.my.jmux` with local docs and host wiring for the tmux/jmux integration.

### Changed
- Wrapped `jmux` so its effective UI prefix follows this repo's tmux prefix (`C-c`) instead of upstream's default `Ctrl-a`.
- Updated tmux/jmux module docs to describe the repo-local `C-c` keybindings and shell alias behavior.
