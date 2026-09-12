# Herdr shell integration

This module owns the launcher, package, optional tmux popup, and writable
`~/.config/herdr/config.toml` bootstrap. Activation updates managed template
keys idempotently without clobbering user settings; a store symlink is unsuitable
because Herdr writes onboarding/settings at runtime.

The read-only `piThemeName` option is consumed by `modules/agents/pi`, which owns
Pi package wiring. Activation installs integrations for enabled agents, including
declared NixOS Hermes profiles.

`tmux/open-herdr.sh` launches Herdr, not tmux. On failure it can fail visibly or
use a plain login shell, not fall back to jmux/tmux and create a startup loop.
Optional `tmux/herdr.conf` popup integration does not transfer startup ownership
from Herdr to tmux.

`modules.shell.herdr.tnote.enable` (default true) installs the packaged tnote CLI
and its Herdr plugin. The config-check VM test disables it so CI does not
evaluate the private `tnote` flake input.
