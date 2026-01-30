# Clawdbot Module

Nix-darwin service module wrapping [nix-clawdbot](https://github.com/clawdbot/nix-clawdbot) for Telegram AI assistant.

## Module Structure

```
modules/services/clawdbot/
├── default.nix   # Module definition
└── AGENTS.md     # This file

config/clawdbot/documents/
├── AGENTS.md     # Bot behavior instructions
├── SOUL.md       # Bot personality
└── TOOLS.md      # Available tools reference
```

## Key Facts

- **Upstream module**: `nix-clawdbot.homeManagerModules.clawdbot`
- **Home-manager integration**: Uses `home-manager.sharedModules` in flake.nix (required for `lib.hm` access)
- **Option path**: `modules.services.clawdbot.*` (wraps `home-manager.users.${user}.programs.clawdbot`)
- **launchd service**: `com.steipete.clawdbot.gateway`

## Configuration Hierarchy

```nix
# This module's options (modules/services/clawdbot)
modules.services.clawdbot.enable
modules.services.clawdbot.telegram.{enable, botTokenFile, allowFrom}
modules.services.clawdbot.anthropic.apiKeyFile
modules.services.clawdbot.plugins.{summarize, peekaboo, oracle, ...}

# Maps to home-manager options
home-manager.users.${user}.programs.clawdbot = {
  enable = true;
  documents = ../../config/clawdbot/documents;
  firstParty.<plugin>.enable = ...;  # NOT plugins = [{source = "github:..."}]
  instances.default = {
    enable = true;
    providers.anthropic.apiKeyFile = ...;
    providers.telegram = { ... };
  };
};
```

## Common Gotchas

1. **lib.hm not found**: Module must be in `home-manager.sharedModules`, not darwin modules list
2. **getFlake on unlocked reference**: Use `firstParty.<plugin>.enable` for built-in plugins, not `plugins = [{source = "github:..."}]`
3. **attribute 'label' missing**: Providers go under `instances.default`, not directly under `programs.clawdbot`

## Manual Config Management (Mac Client)

**The Mac client config `~/.clawdbot/clawdbot.json` is manually managed** via activation script in `hosts/mactraitorpro/default.nix`, NOT by nix-clawdbot module.

**Why:** nix-clawdbot auto-generates `sshTarget` when `gateway.mode = "remote"`, which forces SSH tunnel mode even with `transport: "direct"`. Clawdbot prioritizes `sshTarget` presence over `transport` setting.

### Required Config Structure (Mac)

```json
{
  "gateway": {
    "mode": "remote",
    "remote": {
      "transport": "direct",
      "url": "ws://nuc.cinnamon-rooster.ts.net:18789",
      "token": "<from agenix>"
    }
  },
  "providers": {
    "anthropic": { "apiKey": "<from agenix>" }
  },
  "plugins": { "camsnap": { "enabled": true }, "sonoscli": { "enabled": true } }
}
```

**Critical:** NO `sshTarget` field - its presence triggers SSH tunnel mode regardless of transport setting.

### CLI Commands Overwrite Config

**DO NOT RUN on Mac:**

- `clawdbot doctor`
- `clawdbot config set ...`
- Any CLI command that modifies config

These **overwrite the entire config file**, removing tokens and adding back `sshTarget`.

**Safe commands:**

- `clawdbot gateway status` - Check connection (read-only)

### Restore Config Manually

If config gets reset:

```bash
gateway_token="$(cat ~/.local/share/agenix/clawdbot-bridge-token)"
anthropic_key="$(cat ~/.local/share/agenix/anthropic-api-key)"

cat > ~/.clawdbot/clawdbot.json << EOF
{
  "gateway": { "mode": "remote", "remote": {
    "transport": "direct",
    "url": "ws://nuc.cinnamon-rooster.ts.net:18789",
    "token": "$gateway_token"
  }},
  "providers": { "anthropic": { "apiKey": "$anthropic_key" }},
  "plugins": { "camsnap": { "enabled": true }, "sonoscli": { "enabled": true }}
}
EOF
chmod 600 ~/.clawdbot/clawdbot.json
killall Clawdbot; open -a Clawdbot
```

### Debugging Gateway Connection

```bash
clawdbot gateway status
```

Look for:

```
Remote (configured) ws://nuc.cinnamon-rooster.ts.net:18789
  Connect: ok (31ms) · RPC: ok
```

Check NUC gateway logs:

```bash
ssh nuc "tail -20 /tmp/clawdbot/clawdbot-*.log" | jq '.'
```

### Future Improvements

See beads:

- `dotfiles-kzbo` - Research nix-clawdbot direct connection mode
- `dotfiles-v1z6` - Investigate clawdbot sshTarget vs transport priority

## First-Party Plugins

All available via `firstParty.<name>.enable`:

- `summarize` - Summarize web pages, PDFs, YouTube
- `peekaboo` - Screenshots
- `oracle` - Web search
- `poltergeist` - macOS UI control
- `sag` - Text-to-speech
- `camsnap` - Camera snapshots
- `gogcli` - Google Calendar
- `bird` - Twitter/X
- `sonoscli` - Sonos control
- `imsg` - iMessage

## Secrets

Default paths (plain files):

- `~/.secrets/telegram-bot-token`
- `~/.secrets/anthropic-api-key`

## Verification

```bash
# Check launchd service
launchctl print gui/$(id -u)/com.steipete.clawdbot.gateway | grep state

# View logs
tail -f /tmp/clawdbot/clawdbot-gateway.log
```

## Known Issues

**Python conflict**: Clawdbot bundles whisper (voice transcription) which includes Python 3.13. This conflicts with:

- `modules.dev.python.enable = true` (direct Python env collision)
- `modules.editors.emacs` +jupyter feature (removed to fix conflict)

Error: `pkgs.buildEnv error: two given paths contain a conflicting subpath: .../pydoc3.13`

**Current workaround**: Python module disabled, emacs Jupyter removed. See dotfiles-c11 for details.

## Related Files

- `flake.nix` - nix-clawdbot input and home-manager.sharedModules config
- `hosts/mactraitorpro/default.nix` - Enable with `services.clawdbot.enable = true`
- `config/clawdbot/documents/` - Bot personality and behavior documents
