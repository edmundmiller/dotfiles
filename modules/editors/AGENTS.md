# Editor Modules

Editor packages and `$EDITOR` configuration. The `default.nix` sets `modules.editors.default` (defaults to `"vim"`) which controls the `$EDITOR` environment variable.

## Config Files

Editor dotfiles live in `config/`, not here. These modules just install the package and symlink the config via `home.configFile`.
