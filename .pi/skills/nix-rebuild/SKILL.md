---
name: nix-rebuild
description: >
  Rebuild nix-darwin/NixOS system after dotfiles changes. Use when config files
  managed by Nix (lazygit, ghostty, etc.) need to be regenerated, or after
  editing any .nix file in the dotfiles repo.
---

# Nix System Rebuild

After changing any Nix-managed config in `~/.config/dotfiles`, the system must be rebuilt for changes to take effect. Nix store symlinks are read-only — you cannot edit them in place.

## Quick Rebuild

```bash
cd ~/.config/dotfiles
sudo darwin-rebuild switch --flake .
```

`darwin-rebuild` has a NOPASSWD sudoers rule, so this works non-interactively.

## Using hey

The `hey` command wraps rebuilds:

```bash
hey rebuild    # or: hey re
hey test       # build + activate without boot entry
hey rollback   # roll back to previous generation
```

## When to Rebuild

- After editing any `.nix` file
- After editing config files symlinked through home-manager (lazygit, ghostty, etc.)
- When you see "permission denied" writing to a Nix store path

## Workflow

1. Edit source config in `~/.config/dotfiles/`
2. Commit changes
3. Run `sudo darwin-rebuild switch --flake ~/.config/dotfiles`
4. Verify the symlink now points to updated Nix store path
