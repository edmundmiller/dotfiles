# Openclaw Gateway Module

NixOS service module wrapping [nix-openclaw](https://github.com/openclaw/nix-openclaw) for the NUC gateway.

## Module Structure

```
modules/services/openclaw/
├── default.nix   # Module definition
└── AGENTS.md     # This file

config/openclaw/documents/
├── AGENTS.md     # Bot behavior instructions
├── SOUL.md       # Bot personality
└── TOOLS.md      # Available tools reference
```

## Key Facts

- **Upstream module**: `nix-openclaw.homeManagerModules.openclaw`
- **Home-manager integration**: Uses `home-manager.sharedModules` in flake.nix
- **Option path**: `modules.services.openclaw.*`
- **systemd service**: `openclaw-gateway`

## Configuration Overview

### Gateway

- Mode: local, loopback + Tailscale Serve (HTTPS via MagicDNS)
- Auth: token (agenix) + allowTailscale

### Memory

- Backend: `qmd` (semantic search)
- Citations: `auto`

### CLI Backends (agents.defaults.cliBackends)

- `pi` — via `bunx @mariozechner/pi-coding-agent --print`
- `claude` — `claude --print`
- `codex` — `codex`

### Exec Security

- Mode: `allowlist` with safeBins (cat, ls, find, grep, rg, jq, curl, git, head, tail, wc, sort, uniq, sed, awk, echo, mkdir, cp, mv, rm, touch, chmod, dirname, basename, realpath, which, env, date, diff, tr, tee, xargs)
- Tools profile: `full`

### Bindings

- Default agent bound to telegram DM (user 8357890648)

### Plugins

- `sag` (TTS) — enabled, uses ElevenLabs API key from agenix
- `linear` — custom plugin from dotfiles repo
- Telegram channel enabled

### Models

- Primary: `opencode/minimax-m2.5`
- Fallback: `anthropic/claude-sonnet-4-5`
- Subagent fallback: `anthropic/claude-haiku-4`

## Secrets (agenix)

All injected via ExecStartPre into `$XDG_RUNTIME_DIR/openclaw/env`:

- `anthropic-api-key`
- `opencode-api-key`
- `openai-api-key`
- `elevenlabs-api-key`
- `openclaw-gateway-token` (injected into config JSON via sed)
- `linear-api-token` (passed to linear plugin)

## NUC System Packages

Required by openclaw CLI backends: `claude-code`, `codex`, `bun` (for pi via bunx)

## Verification

```bash
# Check systemd service
systemctl --user status openclaw-gateway

# View logs
journalctl --user -u openclaw-gateway -f

# Test CLI backends
claude --version
codex --version
bunx @mariozechner/pi-coding-agent --version
```

## Known Issues

- **Python conflict**: Openclaw whisper bundles Python 3.13 — conflicts with python module
- **Missing hasown**: Fixed in flake.nix overlay
- **pi not in nixpkgs**: Installed via `bunx` (bun package in systemPackages)

## Related Files

- `modules/desktop/apps/openclaw/` — Mac remote client module
- `flake.nix` — nix-openclaw input and home-manager.sharedModules
- `hosts/nuc/default.nix` — Enables service + installs CLI backend packages
- `hosts/nuc/secrets/secrets.nix` — Agenix secret declarations
- `config/openclaw/documents/` — Bot personality and behavior documents
