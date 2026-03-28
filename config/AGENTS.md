# Config Directory

Dotfile source files that get symlinked into `$XDG_CONFIG_HOME` (and sometimes `$HOME`) by home-manager. These are the **actual config content** — modules in `modules/` wire them into place.

## How Files Get Deployed

Modules use `home.configFile` or `home.file` to symlink config files from this directory into the Nix store, then into the user's home:

```nix
home.configFile."ghostty/config".source = "${configDir}/ghostty/config";
```

The `configDir` variable resolves to this directory (set in `modules/options.nix` as `dotfiles.configDir`).

## Key Rule

**These files are read-only at runtime.** They're symlinks from the Nix store. Edit them here, then rebuild (`sudo /run/current-system/sw/bin/darwin-rebuild switch --flake .`).

## Directory Organization

Each subdirectory maps to a tool or application. Common patterns:

- `config/<tool>/config` or `config/<tool>/config.toml` — main config file
- `config/<tool>/aliases.zsh` — shell aliases sourced via `modules.shell.zsh.rcFiles`
- `config/<tool>/*.lua` — Lua config (nvim, wezterm)

Subdirectories with their own `AGENTS.md` have detailed context — check those when working in that area.

## Adding Config for a New Tool

1. Create `config/<tool>/` with the config files
2. In the corresponding module (`modules/`), add a `home.configFile` entry pointing here
3. Rebuild
