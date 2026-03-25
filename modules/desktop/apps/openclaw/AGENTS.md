# Openclaw Mac App Module

Nix-darwin module for the Openclaw macOS app — remote client connecting to the NUC gateway.

## Module Structure

```
modules/desktop/apps/openclaw/
├── default.nix   # Module definition
└── AGENTS.md     # This file
```

## Key Facts

- **Install method**: Homebrew cask (`openclaw`)
- **Gateway mode**: Remote direct — connects via Tailscale service VIP `wss://openclaw.cinnamon-rooster.ts.net`
- **Option path**: `modules.desktop.apps.openclaw.enable`
- **No local gateway**: `appDefaults.attachExistingOnly = true`
- **No local launchd gateway**: `launchd.enable = false` in remote mode

## Configuration

Instance config at `programs.openclaw.instances.default.config`:

- `gateway.mode = "remote"` — no local gateway process
- `agents.defaults.thinkingDefault = "high"` — default thinking budget
- Gateway token injected at activation from agenix secret
- SSH alias `nuc` is still available in SSH config as a fallback

## Hybrid setup

The module now keeps **Tailscale direct** as the primary connection path:

1. OpenClaw.app runs in remote mode
2. `gateway.remote.transport = "direct"`
3. `gateway.remote.url = "wss://openclaw.cinnamon-rooster.ts.net"`
4. Gateway token is injected from agenix at activation

Separately, dotfiles also provide `ssh nuc` as a fallback/admin path.

This keeps the app on the Tailscale gateway while preserving an SSH alias for troubleshooting or future SSH-based pairing workflows.

## Verification

```bash
# Check launchd service
launchctl print gui/$(id -u)/com.steipete.openclaw.gateway | grep state

# Check remote transport config
cat ~/.openclaw/openclaw.json | jq '.gateway | { mode, remote }'
```

## Debug Logs

- `~/Library/Logs/OpenClaw/diagnostics.jsonl` — app-level diagnostics (connection, pairing, gateway errors)
- Rotated: `diagnostics.jsonl.1`, `.2`, etc.

```bash
# Recent gateway/connection errors
tail -200 ~/Library/Logs/OpenClaw/diagnostics.jsonl | \
  python3 -c "import sys,json; [print(f'{d[\"ts\"]} [{d.get(\"category\",\"\")}] {d[\"event\"]}') for l in sys.stdin if (d:=json.loads(l)) and any(k in d.get('event','').lower() for k in ['gateway','pair','connect','auth','token','wss'])]"
```

## iOS App Pairing

The iOS app connects to the same NUC gateway via Tailscale.

### Prerequisites

- Tailscale connected on iPhone
- Gateway running on NUC (`systemctl --user status openclaw-gateway` on NUC)

### Connect

1. Open **OpenClaw iOS app → Settings → Gateway**
2. Enable **Manual Host**, enter `nuc.cinnamon-rooster.ts.net` (port `18789` or default)
3. Approve the device pairing request on the gateway:

```bash
ssh nuc
openclaw devices list
openclaw devices approve <requestId>
```

### Alternative: Pair via Telegram

If the `device-pair` plugin is enabled:

1. In Telegram, message the bot: `/pair`
2. Copy the setup code (base64 JSON with gateway URL + token)
3. In iOS app → Settings → Gateway, paste the setup code
4. Back in Telegram: `/pair approve`

### Troubleshooting

- **Pairing prompt never appears**: `openclaw devices list` on NUC, approve manually
- **Approved but still fails**: request rotated. Run this loop and approve newest request:
  ```bash
  ssh nuc 'openclaw devices list'
  ssh nuc 'openclaw devices approve <requestId>'
  ```
  Then hard-refresh the Control UI once.
- **Reconnect fails after reinstall**: Keychain token cleared — re-pair the node
- **Can't reach gateway**: Verify Tailscale is connected on both devices (`tailscale status`)

## Related Files

- **openclaw-workspace** repo (`github:edmundmiller/openclaw-workspace`) `module/` — NUC gateway service module (moved from dotfiles)
- `hosts/nuc/default.nix` — NUC host-specific openclaw config (secrets, telegram, cron)
- `hosts/mactraitorpro/default.nix` — Enables with `apps.openclaw.enable = true`
- `modules/shell/ssh.nix` — SSH target used by the macOS app for Remote over SSH
