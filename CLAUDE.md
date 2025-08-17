# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

This is a Nix-based dotfiles repository using Flakes for managing system configurations across macOS (nix-darwin) and NixOS. The primary hosts in use are:
- **Seqeratop**: Work macOS machine with development tools
- **mactraitorpro**: Personal macOS machine

## Essential Commands

**ALWAYS use the `hey` command** (located in `bin/hey`) as the primary interface to this system. The `hey` command is a modular JustScript that provides a clean, consistent interface to all nix-darwin operations.

```bash
# Primary hey commands (ALWAYS USE THESE):
hey rebuild      # Rebuild and switch to new configuration (alias: hey re)
hey test         # Build and activate but don't add to boot menu
hey upgrade      # Update flake inputs and rebuild
hey rollback     # Roll back to previous generation
hey gc           # Run garbage collection
hey check        # Run flake checks
hey show         # Show flake outputs
hey update       # Update flake inputs (alias: hey u)

# Development commands:
hey search <term>    # Search for packages
hey shell <package>  # Start nix shell with package
hey repl            # Start nix repl with flake
```

**Fallback commands** (only use if `hey` is unavailable):
```bash
# Direct darwin-rebuild commands (use only as fallback):
sudo ./result/sw/bin/darwin-rebuild --flake .#MacTraitor-Pro switch  # Rebuild and switch
sudo ./result/sw/bin/darwin-rebuild --flake .#Seqeratop switch       # For Seqeratop host
darwin-rebuild --list-generations       # List available generations
sudo darwin-rebuild --rollback          # Roll back to previous generation
nix-collect-garbage -d                  # Garbage collection
```


## Architecture

The repository follows a modular architecture:

1. **flake.nix**: Entry point defining all inputs and outputs
2. **hosts/*/default.nix**: Machine-specific configurations
3. **modules/**: Reusable configuration modules with a custom options system
4. **lib/**: Helper functions for module management and host configuration
5. **config/**: Application-specific dotfiles and configurations
6. **packages/**: Custom Nix packages and overlays

Configuration flow:
- `flake.nix` → `lib/hosts.nix` → `hosts/<hostname>/default.nix` → enabled modules

## Key Patterns

### Adding/Modifying Host Configuration
Edit `hosts/<hostname>/default.nix` and enable/disable modules:
```nix
modules = {
  some-feature.enable = true;
  desktop.apps.chrome.enable = false;
};
```

### Module System
Modules are defined in `modules/` with options in `modules/options.nix`. They follow the pattern:
```nix
{ options, config, lib, pkgs, ... }:
with lib;
with lib.my;
let cfg = config.modules.<module-name>;
in {
  options.modules.<module-name> = { ... };
  config = mkIf cfg.enable { ... };
}
```

### Managing Secrets
- Credentials are stored in 1Password
- Use `op` CLI for accessing secrets
- Bugwarrior credentials: `bin/setup-bugwarrior-credentials`

## Common Development Tasks

### Testing Configuration Changes
1. Make changes to relevant files
2. Run `hey rebuild` (or `hey re` for short)
3. If issues occur: `hey rollback`

### Updating Dependencies
```bash
hey update                                     # Update all flake inputs
hey update <input>                            # Update specific input
hey upgrade                                   # Update inputs and rebuild system
```

### Adding New Packages
1. For temporary use: `hey shell <package>`
2. For permanent installation, add to host config or relevant module
3. Custom packages go in `packages/`

## Important Conventions

1. **Aliases** are defined in `config/<tool>/aliases.zsh`
2. **Environment variables** in `config/<tool>/env.zsh`
3. **Git configuration** uses includes for work/personal profiles
4. **Task management** uses Taskwarrior with Obsidian sync
5. **Shell** is zsh with extensive customization in `config/zsh/`

## Debugging

- Check current generation: `darwin-rebuild --list-generations`
- View logs: `log show --last 10m | grep -i darwin`
- Flake outputs: `hey show`
- Repl for testing: `hey repl`

## Homebrew Management

This repository uses `nix-homebrew` for proper homebrew integration:
- Homebrew runs with appropriate user privileges (not root)
- Configured with `enableRosetta` for Apple Silicon + Intel compatibility
- `autoMigrate` enabled to migrate existing homebrew installations
- Managed through the `homebrew` section in host configurations

## Notes

- Commands must be run from the repository root
- After major updates, run `nix-collect-garbage -d` to clean old generations
- Host-specific settings override module defaults
- The system uses home-manager for user-level configuration
- **ALWAYS use the `hey` command** - it's a modular JustScript system that provides the primary interface to all nix-darwin operations
- Uses nix-darwin 25.05 with `system.primaryUser` set for proper user context