# NUC Host

Intel NUC home server running NixOS. Primary role: Hermes agents, media services, home automation.

## Key Info

- **Hostname**: nuc
- **Timezone**: America/Chicago
- **SSH**: `ssh nuc` (192.168.1.222 via tailscale, 1Password SSH agent forwarding)
- **Deploy**: `hey nuc` from dotfiles repo (uses deploy-rs, builds remotely on NUC)
- **User**: emiller (password from agenix)

## Nix Settings

- **`sandbox = "relaxed"`** — Required for packages needing network during build (e.g. qmd's bun install). Allows `__noChroot = true` derivations.
- **`programs.nix-ld.enable = true`** — Required for generic linux binaries (e.g. sag from nix-steipete-tools). Libraries: `alsa-lib` (libasound.so.2 for sag audio).

## System Packages (non-module)

| Package                  | Purpose                                               |
| ------------------------ | ----------------------------------------------------- |
| chromium                 | Agent browser control                              |
| nodejs                   | Agent plugins, npm                                 |
| python3                  | node-gyp (native module compilation)                  |
| gcc, gnumake, cmake      | Native compilation (node-gyp, node-llama-cpp)         |
| claude-code, codex       | Agent CLI backends                                 |
| bun                      | Pi CLI backend (`bunx @mariozechner/pi-coding-agent`) |
| qmd                      | llm-agents.nix QMD package                         |
| zele                     | Packaged upstream+patches zele CLI                    |
| sag (nix-steipete-tools) | TTS utility via ElevenLabs                         |
| sqlite                   | General utility                                       |
| taskwarrior3             | Task management                                       |

## QMD (llm-agents.nix)

- **qmd** (thin local wrapper around `pkgs.llm-agents.qmd`) — Hermes memory backend. The real package comes from `numtide/llm-agents.nix`, which upstream QMD contributors explicitly pointed Nix users to in https://github.com/tobi/qmd/pull/285#issuecomment-4012495904.
- Package source: `numtide/llm-agents.nix/packages/qmd/`.
- It uses bun2nix + targeted node-llama-cpp patches instead of our local runtime-bootstrap wrapper.
- Cache/models still live under `~/.cache/qmd/`; patched node-llama-cpp writable state goes under `~/.cache/node-llama-cpp/`; config lives under `~/.config/qmd/`.
- The package includes fixes/workarounds for the stale `bun.lock` problem and NixOS/node-llama-cpp runtime path issues; CUDA works there upstream too.
- On this NUC the local wrapper exports `NODE_LLAMA_CPP_GPU=off`; the upstream Linux default tried Vulkan first, then hit a bad fallback path while cloning/building `llama.cpp`.

## Services

### Hermes Agents

Hermes is the active system-managed agent runtime. Check `systemctl status hermes-agent.service` and profile-specific `hermes-gateway-*` units when debugging.

### Media Stack

- **Jellyfin** — Media server
- **Sonarr/Radarr/Prowlarr** — Media automation
- **Audiobookshelf** — Audiobook/podcast server

### Home Automation

- **Home Assistant** — With PostgreSQL backend, Homebridge, Tailscale
- Extra components: homekit_controller, apple_tv, samsungtv, cast, mobile_app, bluetooth
- **HA state persists across Nix rebuilds** — Automation on/off states, entity states, etc. are stored in `/var/lib/hass/.storage/` and survive `hey nuc` redeploys. Toggling an automation off via API does not need a corresponding Nix change.

### Monitoring

- **Gatus** — Uptime monitoring for all NUC services. See `modules/services/gatus/AGENTS.md`.
  - **Dashboard:** `https://gatus.cinnamon-rooster.ts.net` (Tailscale serve on port 8084)
  - **Alerting:** Telegram (chat 8357890648)
  - **Dead man's switch:** systemd timer checks Gatus health, reports to healthchecks.io every 2 min. Alerts if Gatus OR NUC goes down.
  - **Monitored:** HA, Homebridge, Matter, Jellyfin, Sonarr, Radarr, Prowlarr, PostgreSQL, Tailscale, Hermes Web UI, AgentsView, Audiobookshelf

### Other

- **Docker** — Container runtime
- **Homepage** — Dashboard
- **Taskchampion** — Task sync server
- **Obsidian Sync** — Note sync
- **OpenCode** — AI coding service
- **deploy-rs** — Self-deployment target

## Linear Agent Bridge (OAuth Token Lifecycle)

The NUC runs a **linear-agent-bridge** gateway extension that lets Linear @mentions trigger autonomous agent runs. It authenticates as "Norbot" (an app-user) via OAuth.

### Architecture

```
Linear @mention → webhook → gateway → linear-agent-bridge → agent run
                                ↑
                        LINEAR_API_KEY (from token file)
```

### Token Chain

Linear OAuth tokens expire every 24h. The system auto-rotates them:

1. **Agenix seed** (`linear-api-token.age`, `linear-refresh-token.age`) — bootstrap values, encrypted for edmundmiller + nuc keys
2. **`linear-token-init.service`** (oneshot, runs before gateway) — refreshes token on first boot using the refresh token
3. **`linear-token-refresh.timer`** — fires every 12h, calls the refresh script, restarts gateway
4. **Persisted state** (`~/.local/state/hermes-linear/`) — `token` (access) and `refresh-token` (rotated)

**Critical detail:** Linear rotates refresh tokens on every use. The refresh script persists the new refresh token to `STATE_DIRECTORY/refresh-token`, preferring it over the agenix seed. This prevents token chain death.

### Recovery (when refresh token dies)

Run from your Mac:

```bash
linear-oauth-refresh          # full: re-auth → encrypt → seed → deploy
linear-oauth-refresh --no-deploy  # just tokens, skip hey nuc
```

The script starts a callback server on `:9999`, opens the OAuth consent page, exchanges the code, encrypts with agenix, seeds on NUC, and deploys. Requires: logged into Linear in browser, SSH access to NUC.

### Smoke Test

```bash
bin/test-linear-agent          # fires fake webhook, tails gateway log
```

Expect: HTTP 202, `agentActivityCreate failed: Entity not found: AgentSession` (normal — test uses fake session ID).

### Key Files

| File                                         | Purpose                             |
| -------------------------------------------- | ----------------------------------- |
| `hosts/nuc/default.nix` (lines 12-43)        | Refresh script with persist logic   |
| `bin/linear-oauth-refresh`                   | Manual re-bootstrap from Mac        |
| `bin/test-linear-agent`                      | Smoke test script                   |
| `hosts/nuc/secrets/linear-api-token.age`     | Agenix-encrypted access token seed  |
| `hosts/nuc/secrets/linear-refresh-token.age` | Agenix-encrypted refresh token seed |

### OAuth App Details

- **Client ID:** `c64c969674a02fccc863d4aa950ec132`
- **Redirect:** `http://localhost:9999/callback`
- **Scopes:** `read,write,issues:create,comments:create,app:assignable,app:mentionable`
- **Actor:** `app` (app-user tokens, not personal)

## Secrets (agenix)

Located in `hosts/nuc/secrets/`:

- `emiller_password.age` — User password
- `anthropic-api-key.age` — Claude API
- `opencode-api-key.age` — OpenCode API
- `openai-api-key.age` — OpenAI API
- `gemini-api-key.age` — Gemini API
- `elevenlabs-api-key.age` — ElevenLabs TTS
- `telegram-bot-token.age` — Telegram bot token (used by Gatus alerting)
- `linear-api-token.age` — Linear OAuth access token (see Linear Agent Bridge section)
- `linear-refresh-token.age` — Linear OAuth refresh token (see Linear Agent Bridge section)
- `linear-webhook-secret.age` — Linear webhook signature verification

## Deployment

Two mechanisms, both pull from GitHub:

| Method                | Trigger            | Source                                              |
| --------------------- | ------------------ | --------------------------------------------------- |
| `hey nuc`             | Manual (deploy-rs) | Local flake eval → remote build on NUC              |
| `nixos-upgrade.timer` | Daily 04:40        | `github:edmundmiller/dotfiles#nuc` with `--refresh` |

**Manual rebuild on NUC** (no local clone needed):

```bash
ssh nuc "sudo nixos-rebuild switch --refresh --flake github:edmundmiller/dotfiles#nuc"
```

Config: `hosts/_server.nix` — `system.autoUpgrade.flake = "github:edmundmiller/dotfiles#${hostname}"`.

### Worktree Testing

When testing uncommitted NUC changes from a secondary Git worktree (Herdr/side-agent/etc.), prefer the worktree deploy helper instead of `hey nuc`:

```bash
hey nuc-wt build          # safest first check: remote build only
hey nuc-wt                # default: dry-activate from the synced worktree
hey nuc-wt test           # activate until next reboot, but do not set boot generation
hey nuc-wt switch         # real deploy from this worktree
hey nuc-wt vm             # build the NUC VM derivation on the NUC
```

`hey nuc-wt` rsyncs the current local worktree to `/tmp/dotfiles-worktree-$USER` on the NUC and runs `nixos-rebuild` there. This lets agents test uncommitted worktree changes without pushing or modifying the canonical checkout used by normal deployment.

The rsync intentionally excludes local-only/heavy directories like `.git/`, `.pi/`, `node_modules/`, `result`, and caches. If a worktree deploy seems slow or stuck, check for unexpected large local directories before changing deployment logic:

```bash
du -sh . ./* ./.??* 2>/dev/null | sort -h | tail
du -sh .pi/side-agents/runtime/* 2>/dev/null | sort -h | tail
```

## Gotchas

- **Deploy builds remotely**: `hey nuc` evaluates locally but builds on NUC. Large rebuilds (home-assistant, etc.) take time.
- **No local dotfiles clone on NUC**: Removed `~/dotfiles-deploy` — auto-upgrade fetches from GitHub directly. Don't recreate it.
- **`tnote` path is canonicalized**: `~/.local/bin/tnote` points at `~/src/personal/tnote`. No legacy `tn-monorepo` fallback is kept; fix the canonical repo path directly if `tnote` is stale or missing.
- **Scintillate vault path nuance**: declarative config points Hermes/Scintillate at `/home/hermes/repos/obsidian-vault`, but Docker may show the bind mount as `/home/emiller/obsidian-vault -> /home/emiller/obsidian-vault`. That is expected as long as `docker exec hermes-agent-scintillate realpath /home/hermes/repos/obsidian-vault` resolves to `/home/emiller/obsidian-vault` and `.git` exists there.
- **New agenix secrets**: If a first deploy lands new secrets before a service has picked them up, verify the current gateway/service model before restarting anything. On the current NUC, Hermes runs as system service `hermes-agent.service`, so check `sudo systemctl status hermes-agent.service` and restart that if needed. `systemctl --user restart openclaw-gateway` only applies to older OpenClaw deployments.
- **QMD now comes from llm-agents.nix**: if packaging breaks again, check `numtide/llm-agents.nix/packages/qmd/` and the upstream QMD note at https://github.com/tobi/qmd/pull/285#issuecomment-4012495904 before reviving a local wrapper.
- **nix-ld libraries**: Any new generic linux binary that fails with "cannot run dynamically linked executable" needs its missing libs added to `programs.nix-ld.libraries`. Use `ldd /path/to/binary` to find missing `.so` files.
- **ZFS/znapzend**: Currently disabled (FIXME). Backup config exists but not active.
- **Logrotate**: `checkConfig = false` due to missing group 30000 issue.

## Related Files

- `hosts/nuc/hardware-configuration.nix` — Hardware/boot config
- `hosts/nuc/disko.nix` — Disk partitioning
- `hosts/nuc/backups.nix` — Backup configuration
- `hosts/nuc/secrets/secrets.nix` — Agenix secret declarations
- `modules/services/gatus/` — Uptime monitoring module + AGENTS.md
- `hosts/nuc/DEPLOY.md` — Deployment documentation
