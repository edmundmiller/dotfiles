# Editor Modules

Editor packages and `$EDITOR` configuration. The `default.nix` sets `modules.editors.default` (defaults to `"vim"`) which controls the `$EDITOR` environment variable.

## Files

| File                   | Editor         | Key Details                         |
| ---------------------- | -------------- | ----------------------------------- |
| `vim.nix`              | Neovim         | Wraps neovim, config lives in `config/nvim/` |
| `emacs.nix`            | Emacs          | Doom Emacs setup                    |
| `code.nix`             | VS Code        | Visual Studio Code                  |
| `helix.nix`            | Helix          | Modal editor                        |
| `file-associations.nix`| —              | MIME type → editor mappings         |

## Config Files

Editor dotfiles live in `config/`, not here:

- **Neovim**: `config/nvim/` (has its own `AGENTS.md`)
- **Emacs**: `config/emacs/`
- **VS Code**: `config/Code/`

These modules just install the package and symlink the config.
