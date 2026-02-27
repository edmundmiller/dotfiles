# NUC Host

Intel NUC home server running NixOS. Primary role: openclaw gateway, media services, home automation.

## Key Info

- **Hostname**: nuc
- **Timezone**: America/Chicago
- **SSH**: `ssh nuc` (192.168.1.222 via tailscale, 1Password SSH agent forwarding)
- **Deploy**: `hey nuc` from dotfiles repo (uses deploy-rs, builds remotely on NUC)
- **User**: emiller (password from agenix)

## Nix Settings

- **`sandbox = "relaxed"`** — Required for packages needing network during build (e.g. qmd's bun install). Allows `__noChroot = true` derivations.
- **`programs.nix-ld.enable = true`** — Required for generic linux binaries (e.g. sag from nix-steipete-tools). Libraries: `alsa-lib` (libasound.so.2 for sag audio).
- **`/bin` compat symlinks** — `cat`, `ln`, `mkdir`, `rm` symlinked for nix-openclaw activation scripts.

## System Packages (non-module)

| Package                  | Purpose                                               |
| ------------------------ | ----------------------------------------------------- |
| chromium                 | Openclaw browser control                              |
| nodejs                   | Openclaw plugins, npm                                 |
| python3                  | node-gyp (native module compilation)                  |
| gcc, gnumake, cmake      | Native compilation (node-gyp, node-llama-cpp)         |
| claude-code, codex       | Openclaw CLI backends                                 |
| bun                      | Pi CLI backend (`bunx @mariozechner/pi-coding-agent`) |
| sag (nix-steipete-tools) | TTS for openclaw via ElevenLabs                       |
| sqlite                   | General utility                                       |
| taskwarrior3             | Task management                                       |

## npm Global Packages (NOT nix-managed)

- **qmd** (`@tobilu/qmd`) — Openclaw memory backend. Installed via `npm install -g @tobilu/qmd`. Accessed via `~/.local/bin/qmd-wrapper` (forces correct node version in PATH). After node upgrades: `cd ~/.cache/npm/lib/node_modules/@tobilu/qmd && npm rebuild better-sqlite3`.

## Services

### Openclaw Gateway

See `modules/services/openclaw/AGENTS.md` for full details.

- Gateway mode: local + tailscale serve
- Memory: qmd backend
- CLI backends: pi, claude, codex
- Telegram bot + ElevenLabs TTS (sag)

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
  - **Alerting:** Telegram (chat 8357890648) + OpenClaw webhook (`/hooks/wake`)
  - **Dead man's switch:** systemd timer checks Gatus health, reports to healthchecks.io every 2 min. Alerts if Gatus OR NUC goes down.
  - **Monitored:** HA, Homebridge, Matter, Jellyfin, Sonarr, Radarr, Prowlarr, PostgreSQL, Tailscale, OpenClaw, Audiobookshelf

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
4. **Persisted state** (`~/.local/state/openclaw-linear/`) — `token` (access) and `refresh-token` (rotated)

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
- `elevenlabs-api-key.age` — ElevenLabs TTS
- `openclaw-gateway-token.age` — Gateway auth
- `openclaw-hooks-token.age` — OpenClaw hooks auth (used by Gatus webhook alerting)
- `telegram-bot-token.age` — Telegram bot token (used by Gatus alerting)
- `linear-api-token.age` — Linear OAuth access token (see Linear Agent Bridge section)
- `linear-refresh-token.age` — Linear OAuth refresh token (see Linear Agent Bridge section)
- `linear-webhook-secret.age` — Linear webhook signature verification
- `goose-auth-token.age` — Goose auth

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

## Gotchas

- **Deploy builds remotely**: `hey nuc` evaluates locally but builds on NUC. Large rebuilds (home-assistant, etc.) take time.
- **No local dotfiles clone on NUC**: Removed `~/dotfiles-deploy` — auto-upgrade fetches from GitHub directly. Don't recreate it.
- **New agenix secrets**: ExecStartPre env injection may run before agenix decrypts new secrets on first deploy. Restart the service after: `systemctl --user restart openclaw-gateway`.
- **Node version churn**: NUC has nodejs from home-manager. When it upgrades, native modules (better-sqlite3 in qmd) break. Fix: `npm rebuild better-sqlite3` in qmd's node_modules.
- **nix-ld libraries**: Any new generic linux binary that fails with "cannot run dynamically linked executable" needs its missing libs added to `programs.nix-ld.libraries`. Use `ldd /path/to/binary` to find missing `.so` files.
- **ZFS/znapzend**: Currently disabled (FIXME). Backup config exists but not active.
- **Logrotate**: `checkConfig = false` due to missing group 30000 issue.

## Related Files

- `hosts/nuc/hardware-configuration.nix` — Hardware/boot config
- `hosts/nuc/disko.nix` — Disk partitioning
- `hosts/nuc/backups.nix` — Backup configuration
- `hosts/nuc/secrets/secrets.nix` — Agenix secret declarations
- `modules/services/openclaw/` — Gateway module + AGENTS.md
- `modules/services/gatus/` — Uptime monitoring module + AGENTS.md
- `hosts/nuc/DEPLOY.md` — Deployment documentation
