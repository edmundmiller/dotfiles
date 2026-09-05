# Jmux

Local patches to `jarredkenny/jmux` align UI interception with tmux: wrapper
defaults are `JMUX_PREFIX_KEY=C-c` and `JMUX_NEW_SESSION_KEY=M`. Lowercase `n`
remains tmux next-window. Preserve batched prefix chunks (e.g. `C-cg`) and
matching welcome/help text.

The wrapper supplies tmux/git PATH. `modules.shell.tmux.jmux.package` selects
`pkgs.my.jmux` for Ghostty and generated launchers; changing a package alone
does not activate it on a host.
