# Dev — Language Toolchain Modules

Each file enables a language toolchain via `modules.dev.<lang>.enable`. Installs compilers, package managers, and sets up environment variables (XDG-compliant where possible).

## Pattern

```nix
modules.dev.<lang> = {
  enable = mkBoolOpt false;
  enableGlobally = mkBoolOpt false;  # some have this for PATH-level install
};
```

Enabled per-host in `hosts/<hostname>/default.nix`.
