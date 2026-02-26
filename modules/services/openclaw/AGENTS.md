# Openclaw Gateway Module

NixOS service module wrapping [nix-openclaw](https://github.com/openclaw/nix-openclaw) for the NUC gateway.

## Module Structure

```
modules/services/openclaw/
├── default.nix   # Module definition
├── AGENTS.md     # This file
└── documents/
    ├── AGENTS.md
    ├── HEARTBEAT.md  # Agent reads this during external heartbeat checks
    ├── SOUL.md
    └── TOOLS.md
```

## Key Facts

- **Upstream module**: `nix-openclaw.homeManagerModules.openclaw`
- **Home-manager integration**: Uses `home-manager.sharedModules` in flake.nix
- **Option path**: `modules.services.openclaw.*`
- **systemd service**: `openclaw-gateway`
- **Bot documents**: `./documents/` (AGENTS.md, SOUL.md, TOOLS.md)

## Configuration Overview

### Gateway

- Mode: local, loopback + Tailscale Serve (HTTPS via MagicDNS)
- Auth: token (agenix) + allowTailscale

### Memory

- Backend: `qmd` (semantic search)
- Citations: `auto`

### Claude Max Proxy

- **Service**: `claude-max-api-proxy` (systemd user service)
- **Package**: `pkgs.my.claude-max-api-proxy` (built from GitHub via `buildNpmPackage`)
- **Port**: 3456 (default), configurable via `claudeMaxProxy.port`
- **Provider name**: `claude-max` — models: `claude-max/claude-opus-4`, `claude-max/claude-sonnet-4`, `claude-max/claude-haiku-4`
- **Requires**: `claude` CLI authenticated on the NUC (already in systemPackages)
- **Dependency**: openclaw-gateway `Requires` + `After` the proxy service
- **Enable**: `modules.services.openclaw.claudeMaxProxy.enable = true`

### External Heartbeat Monitor

- **Architecture**: systemd user timer → triggers `openclaw agent` → pings healthchecks.io
- **Why external**: built-in heartbeat runs inside the gateway process — if gateway crashes/hangs, it stops too. External timer detects that.
- **Timer**: `openclaw-heartbeat-monitor.timer` — every 30m (configurable), 2m random jitter, starts 5m after boot
- **Service**: `openclaw-heartbeat-monitor.service` — oneshot, 5m timeout
- **Flow**: ping `/start` → run agent with HEARTBEAT.md prompt → ping success (with output) or `/fail`
- **Document**: `documents/HEARTBEAT.md` — agent reads this for self-diagnostic instructions
- **Enable**: `modules.services.openclaw.heartbeatMonitor.enable = true` + set `pingUrl`
- **healthchecks.io UUID**: `71a6388a-9ed5-4edd-b2a9-e5616dec4091`

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
- `linear` — CLI plugin from dotfiles repo (curl/jq GraphQL wrapper)
- `linear-agent-bridge` — gateway extension: webhook handler for Linear Agent Sessions
- Telegram channel enabled

### Webhook Proxy (Linear Agent Bridge)

- **Architecture**: nginx (method-restricted) → Tailscale Funnel (path-restricted)
- **Public URL**: `https://nuc.cinnamon-rooster.ts.net:8443/plugins/linear/linear`
- **Tailscale Serve (port 443)**: full gateway, tailnet-only (unchanged)
- **Tailscale Funnel (port 8443)**: only `/plugins/linear/*`, public internet
- **nginx (127.0.0.1:8444)**: only POST allowed, proxies to gateway port 18789
- **Security layers**: path restriction (Tailscale) → method restriction (nginx) → HMAC-SHA256 (plugin) → per-session bearer tokens (agent API)
- **systemd service**: `tailscale-funnel-linear` (oneshot, configures serve+funnel)
- **Gateway extensions**: symlinked from nix store to `~/.openclaw/extensions/`

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

## Troubleshooting

### Quick Health Check

SSH in and run `openclaw doctor` with the gateway's env vars:

```bash
ssh nuc
source <(sed "s/^/export /" /run/user/1000/openclaw/env)
export OPENCLAW_AUTH_TOKEN=$(cat /run/agenix/openclaw-gateway-token)
openclaw doctor
```

This checks config validity, plugin status, channel connectivity (telegram), skills, and security.

### Send a Test Message

Same env setup, then:

```bash
openclaw agent --agent main -m "Hello, test message"
```

### Check Logs

```bash
# Simple gateway log (human-readable)
cat /tmp/openclaw/openclaw-gateway.log

# Detailed JSON log (structured, verbose)
cat /tmp/openclaw/openclaw-2026-02-16.log  # date-stamped

# Grep for errors
grep -iE 'error|fail' /tmp/openclaw/openclaw-gateway.log

# Clean slate (truncate + restart)
truncate -s 0 /tmp/openclaw/openclaw-gateway.log
systemctl --user restart openclaw-gateway
```

### Service Management

```bash
systemctl --user status openclaw-gateway
systemctl --user restart openclaw-gateway
journalctl --user -u openclaw-gateway -f
```

### qmd Memory

```bash
# Check qmd status
~/.local/bin/qmd-wrapper status

# Rebuild better-sqlite3 after node upgrades (use system node!)
cd ~/.cache/npm/lib/node_modules/@tobilu/qmd
PATH=/run/current-system/sw/bin:$PATH npm rebuild better-sqlite3
systemctl --user restart openclaw-gateway
```

### Test CLI Backends

```bash
claude --version
codex --version
bunx @mariozechner/pi-coding-agent --version
```

### Check Claude Max Proxy

```bash
# Service status
systemctl --user status claude-max-api-proxy

# Health check
curl http://localhost:3456/health

# List models
curl http://localhost:3456/v1/models

# Test completion
curl http://localhost:3456/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{"model": "claude-sonnet-4", "messages": [{"role": "user", "content": "Hello!"}]}'
```

## Known Issues & Gotchas

- **Python conflict**: Openclaw whisper bundles Python 3.13 — conflicts with python module
- **Missing hasown**: Fixed in flake.nix overlay
- **pi not in nixpkgs**: Installed via `bunx` (bun package in systemPackages)
- **qmd installed via npm, NOT nix**: The qmd flake (`github:tobi/qmd`) fails in nix sandbox (bun install needs network). Even with `sandbox = "relaxed"` + `__noChroot = true`, the resulting nix store binary has read-only filesystem issues (`node-llama-cpp` tries to write to its own dir). Solution: `npm install -g @tobilu/qmd` on NUC, accessed via `~/.local/bin/qmd-wrapper` which forces the correct system node in PATH.
- **qmd node version mismatch**: NUC has two node versions — system v24 (`/run/current-system/sw/bin/node`) and user-profile v25 (`/etc/profiles/per-user/emiller/bin/node`). The `qmd-wrapper` pins system node first in PATH so gateway and CLI use the same version. After any node upgrade, rebuild: `cd ~/.cache/npm/lib/node_modules/@tobilu/qmd && PATH=/run/current-system/sw/bin:$PATH npm rebuild better-sqlite3`.
- **sag binary needs nix-ld**: `nix-steipete-tools` produces generic linux binaries. NUC needs `programs.nix-ld.enable = true` + `alsa-lib` in `programs.nix-ld.libraries` for sag's `libasound.so.2` dependency.
- **claude-max-api-proxy needs authenticated claude CLI**: The proxy calls `claude` under the hood. If auth expires, the proxy service will fail on startup (it verifies auth). Re-authenticate with `claude auth login` on the NUC.
- **tools config is top-level**: `tools.exec.safeBins` and `tools.profile` go under `config.tools`, NOT `config.agents.defaults.tools` (the latter doesn't exist).
- **darwinOnlyFiles/nixosOnlyFiles in default.nix**: When converting a module from `.nix` to directory (`/default.nix`), MUST update the path AND ensure the directory is git-tracked (untracked dirs invisible to nix flakes).
- **ExecStartPre vs agenix timing**: On first deploy with a new secret, the env file may be written before agenix decrypts the new key. Restart the service after deploy: `systemctl --user restart openclaw-gateway`.
- **bundledPlugins.sag**: Installs sag as a SKILL (SKILL.md teaching the agent to call the `sag` CLI), not as a gateway plugin. The sag binary must be in system PATH separately.

## Skills

Two mechanisms for providing skills to openclaw:

- **`sharedSkills`** — cherry-picks from the `agent-skills-nix` bundle (same skills used by coding agents). Symlinked from `programs.agent-skills.bundlePath` into `~/.openclaw/workspace/skills/`.
- **`skills`** — inline skill definitions (name, description, body). Written as `SKILL.md` files. Use for openclaw-only skills like `obsidian-vault`.

Shared skill list configured in `hosts/nuc/default.nix`.

## Related Files

- `packages/claude-max-api-proxy.nix` — Nix package for the proxy
- `modules/desktop/apps/openclaw/` — Mac remote client module
- `flake.nix` — nix-openclaw input and home-manager.sharedModules
- `hosts/nuc/default.nix` — Enables service + installs CLI backend packages
- `hosts/nuc/secrets/secrets.nix` — Agenix secret declarations
- `./documents/` — Bot personality and behavior documents
