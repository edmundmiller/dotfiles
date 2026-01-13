# Claude CLI Module

Claude Code shell integration for nix-darwin. Manages settings, agents, skills, and WakaTime integration.

## Installation

Enable in host config:

```nix
modules.shell.claude.enable = true;
```

## What This Module Provides

- **Settings symlink:** `~/.claude/settings.json` -> nix store
- **Session instructions:** `~/.claude/CLAUDE.md` -> nix store
- **Shared agents/skills:** Symlinked from OpenCode config (single source of truth)
- **WakaTime integration:** API key via agenix secret decryption

## Files

| Source | Destination | Purpose |
|--------|-------------|---------|
| `config/claude/settings.json` | `~/.claude/settings.json` | CLI settings, marketplaces |
| `config/claude/CLAUDE.md` | `~/.claude/CLAUDE.md` | Per-session instructions |
| `config/opencode/agent/` | `~/.claude/agents/` | Custom agents (shared) |
| `config/opencode/skill/` | `~/.claude/skills/` | Custom skills (shared) |

## Plugin Management

Plugins are **NOT** managed by nix. Install manually:

```bash
# From official marketplace
claude plugin install <plugin-name>

# From custom marketplace (defined in settings.json)
claude plugin marketplace add <marketplace-name>
claude plugin install <marketplace>@<plugin>
```

Plugin directories:
- System plugins: `~/.claude/plugins/`
- Local dev: `config/claude/plugins/` (for testing)

## WakaTime Integration

WakaTime API key is stored as an agenix secret and referenced via vault command:

```ini
# Generated ~/.wakatime.cfg
[settings]
api_key_vault_cmd = cat /path/to/decrypted/wakatime-api-key
```

Requires agenix secret `wakatime-api-key` to be configured.

## Troubleshooting

### Settings validation errors

If you see schema validation errors for `extraKnownMarketplaces`, check the format in `config/claude/settings.json`. See AGENTS.md for correct schema.

### Plugins not found after rebuild

Plugins are user-managed and persist across rebuilds. If missing:

```bash
claude plugin list              # Check installed plugins
claude plugin marketplace list  # Check available marketplaces
```

### WakaTime not tracking

1. Verify secret exists: `ls ~/.config/agenix/`
2. Check wakatime config: `cat ~/.wakatime.cfg`
3. Test API key: `wakatime --today`
