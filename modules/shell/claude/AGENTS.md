# Claude CLI Module - Agent Guide

## Purpose

Nix module for Claude Code CLI. Manages settings, shared agents/skills, and WakaTime integration.

## Module Structure

```
modules/shell/claude/
├── default.nix   # Module definition
├── README.md     # Human docs
└── AGENTS.md     # This file

config/claude/
├── settings.json # CLI settings (symlinked to ~/.claude/)
├── CLAUDE.md     # Per-session instructions
└── plugins/      # Local plugin development (NOT deployed)

config/opencode/
├── agent/        # Shared agents (symlinked to ~/.claude/agents/)
└── skill/        # Shared skills (symlinked to ~/.claude/skills/)
```

## Key Facts

- **Agents/skills:** Shared with OpenCode (single source of truth in `config/opencode/`)
- **Settings:** Nix-managed (symlinked from store, read-only)
- **Plugins:** NOT nix-managed (user installs manually)
- **WakaTime:** API key via agenix secret decryption (Darwin only)

## extraKnownMarketplaces Schema

The `source` property must be an **object**, not a string:

```json
// CORRECT
"extraKnownMarketplaces": {
  "marketplace-name": {
    "source": {
      "source": "github",
      "repo": "owner/repo-name"
    }
  }
}

// WRONG - will cause validation error
"extraKnownMarketplaces": {
  "marketplace-name": {
    "source": "github",
    "repo": "owner/repo-name"
  }
}
```

## Common Issues

**Settings validation error** -> Check `extraKnownMarketplaces` schema format above

**Plugins missing** -> Plugins are user-managed, not deployed by nix

**WakaTime not working** -> Requires agenix secret `wakatime-api-key`

## Related Files

- `modules/shell/opencode.nix` - Sibling module (shares agent/skill directories)
- `config/claude/plugins/*/` - Local plugin development directories
- `hosts/*/default.nix` - Enable with `modules.shell.claude.enable = true`
