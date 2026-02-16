# OpenClaw Mac App Module

Nix-darwin module for the OpenClaw macOS app — remote client connecting to the NUC gateway.

## Module Structure

```
modules/desktop/apps/openclaw/
├── default.nix   # Module definition
└── AGENTS.md     # This file
```

## Key Facts

- **Install method**: Homebrew cask (`openclaw`)
- **Gateway mode**: Remote — connects to NUC via `wss://nuc.cinnamon-rooster.ts.net`
- **Option path**: `modules.desktop.apps.openclaw.enable`
- **No local gateway**: `appDefaults.attachExistingOnly = true`
- **launchd managed**: `launchd.enable = true` for background connectivity

## Configuration

Instance config at `programs.openclaw.instances.default.config`:

- `gateway.mode = "remote"` — no local gateway process
- `agents.defaults.thinkingDefault = "high"` — default thinking budget
- Gateway token injected at activation from agenix secret

## Token Injection

Config is a Nix store symlink (read-only). The `openclawInjectToken` activation script:

1. Copies the symlinked config to a regular file
2. Replaces `__OPENCLAW_TOKEN_PLACEHOLDER__` with the agenix secret
3. Moves the patched file into place

## Related Files

- `modules/services/openclaw/` — NUC gateway service (server side)
- `config/openclaw/documents/` — Bot personality and behavior docs
- `hosts/mactraitorpro/default.nix` — Enables with `apps.openclaw.enable = true`
- `hosts/shared/secrets/openclaw-gateway-token.age` — Auth token (agenix)
