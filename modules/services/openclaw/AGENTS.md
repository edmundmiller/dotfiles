# Openclaw Module

Nix-darwin/NixOS service module wrapping [nix-openclaw](https://github.com/openclaw/nix-openclaw) for Telegram AI assistant.

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
- **Home-manager integration**: Uses `home-manager.sharedModules` in flake.nix (required for `lib.hm` access)
- **Option path**: `modules.services.openclaw.*` (wraps `home-manager.users.${user}.programs.openclaw`)
- **launchd service** (macOS): `com.steipete.openclaw.gateway`
- **systemd service** (Linux): `openclaw-gateway`

## Configuration Hierarchy

```nix
# This module's options (modules/services/openclaw)
modules.services.openclaw.enable
modules.services.openclaw.gatewayToken  # Auth token for gateway
modules.services.openclaw.telegram.{enable, botTokenFile, allowFrom}
modules.services.openclaw.plugins    # Custom plugins ({ source = "github:..."; })
modules.services.openclaw.firstParty # First-party plugin toggles

# Maps to home-manager options
home-manager.users.${user}.programs.openclaw = {
  enable = true;
  documents = ../../config/openclaw/documents;

  config = {
    gateway = {
      mode = "local";
      auth.token = "...";
    };
    channels.telegram = {
      tokenFile = "...";
      allowFrom = [...];
      groups."*".requireMention = true;
    };
  };

  firstParty.zele.enable = true;
  plugins = [{ source = "github:..."; }];

  instances.default = {
    enable = true;
  };
};
```

## Secrets

Default paths (plain files):

- `~/.secrets/telegram-bot-token`
- Gateway token: inline in config (TODO: use agenix/opnix)

## Verification

```bash
# macOS - Check launchd service
launchctl print gui/$(id -u)/com.steipete.openclaw.gateway | grep state

# Linux - Check systemd service
systemctl --user status openclaw-gateway

# View logs
tail -f /tmp/openclaw/openclaw-gateway.log  # macOS
journalctl --user -u openclaw-gateway -f     # Linux
```

## Known Issues

**Python conflict**: Openclaw bundles whisper (voice transcription) which includes Python 3.13. This conflicts with:

- `modules.dev.python.enable = true` (direct Python env collision)
- `modules.editors.emacs` +jupyter feature

Error: `pkgs.buildEnv error: two given paths contain a conflicting subpath: .../pydoc3.13`

**Workaround**: Python module disabled where openclaw is enabled.

**Missing hasown module**: `openclaw-gateway` crashes with `Cannot find module 'hasown'` (form-data). Fix is in `flake.nix` overlay adding `node_modules/hasown`.

## Google + Linear setup (nuc)

- Enable zele via `modules.services.openclaw.firstParty.zele.enable = true;`
- Add Linear plugin via `modules.services.openclaw.plugins` (customPlugins)
- Secrets (agenix):
  - `/run/agenix/zele-client-secret` (Google OAuth client secret JSON)
  - `/run/agenix/linear-api-token` (Linear API key)
- OAuth setup (once, on nuc):
  - `gog auth credentials /run/agenix/zele-client-secret`
  - `gog auth add you@gmail.com --services gmail,calendar`

## Related Files

- `flake.nix` - nix-openclaw input and home-manager.sharedModules config
- `hosts/*/default.nix` - Enable with `services.openclaw.enable = true`
- `config/openclaw/documents/` - Bot personality and behavior documents
