# Config sources

This directory owns dotfile content; `modules/` owns deployment through
`home.configFile` / `home.file`. `configDir` is `dotfiles.configDir` from
`modules/options.nix`. Most deployed files are read-only store symlinks;
activation uses `hey re` when requested.

Tool shell integration belongs in `config/<tool>/env.zsh` (environment/PATH)
or `aliases.zsh` (interactive setup), discovered by the zsh module. Writable
bootstrap exceptions, including Claude and Herdr, are documented in their scope.
