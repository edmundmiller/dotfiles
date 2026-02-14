# Neovim Config

Single-file kickstart-based config. `init.lua` is the entire setup.

## History

Previous config was AstroNvim with ~40 plugin files, custom nextflow tooling, snippets, and a separate kickstart fork. All removed in `a1b69cb3`. Reference that commit for anything that needs to be recovered.

## Structure

```
config/nvim/
├── init.lua              # Everything
├── lua/custom/plugins/   # Custom plugin specs
└── lua/kickstart/        # Kickstart modules (health, debug, lint, etc.)
```

## Managed by Nix

This directory is symlinked from the Nix store — **read-only at runtime**. Edit source files here, then `hey rebuild`.
