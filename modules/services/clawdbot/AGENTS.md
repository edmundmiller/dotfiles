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

## Related Files

- `flake.nix` - nix-clawdbot input and home-manager.sharedModules config
- `hosts/mactraitorpro/default.nix` - Enable with `services.clawdbot.enable = true`
- `config/clawdbot/documents/` - Bot personality and behavior documents
