# Openclaw Config

Openclaw bot personality and behavior documents, shared across both modules.

## Structure

```
config/openclaw/documents/
├── AGENTS.md   # Bot behavior instructions and tool capabilities
├── SOUL.md     # Bot personality and tone
└── TOOLS.md    # Available tools reference
```

## Usage

Linked via `programs.openclaw.documents` in both modules:

- `modules/services/openclaw/` — NUC gateway (server)
- `modules/desktop/apps/openclaw/` — Mac app (remote client)

These files are NOT Nix config — they're plain markdown injected into the Openclaw bot's context at runtime.
