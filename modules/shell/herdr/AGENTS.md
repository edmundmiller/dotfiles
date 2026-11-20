# Herdr deployment

`default.nix` declares enablement and optional tnote support. `native.nix` checks the installer-owned `hc`; `native.app.enable` defaults to Darwin and gates app preferences, mods and helpers. Servers receive core-only configuration. The legacy terminal multiplexer is retired.

Activation reconciles only managed leaves of writable settings, keys and programs. Preserve other preferences, shipped assets, sessions, worktrees, app state and generated files. Preserve the signed native bundle. Missing binaries produce an installation hint, not a network install during activation.

Keep the old-agent-hook cleanup, which removes obsolete socket integrations without changing native OSC 7501 reporting. Native Herdr owns its palette independently of Ghostty and Pi.

Run `hey check modules/shell/herdr config/herdr` and the native CLI/config behavior tests. Add Darwin evaluation for cross-module wiring changes. Activation and live session commands require authority.
