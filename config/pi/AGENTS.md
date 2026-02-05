# Pi Coding Agent Configuration

This directory contains pi coding agent settings managed via nix.

## Documentation

- [Settings](https://github.com/badlogic/pi-mono/blob/main/packages/coding-agent/docs/settings.md) - All config options
- [Packages](https://github.com/badlogic/pi-mono/blob/main/packages/coding-agent/docs/packages.md) - Install/manage extensions via npm/git
- [Skills](https://github.com/badlogic/pi-mono/blob/main/packages/coding-agent/docs/skills.md) - Agent skills system
- [Prompt Templates](https://github.com/badlogic/pi-mono/blob/main/packages/coding-agent/docs/prompt-templates.md) - Reusable prompts
- [Extensions](https://github.com/badlogic/pi-mono/blob/main/packages/coding-agent/docs/extensions.md) - Custom tools, commands, event hooks

## Files

- `settings.jsonc` — Source config (JSONC with comments + trailing commas)
- `settings-schema.json` — JSON Schema derived from pi's `Settings` TypeScript interface
- Nix strips comments and trailing commas → `~/.pi/agent/settings.json`

## Validating Settings

```bash
# Validate settings.jsonc against the schema (requires jsonschema: pip install jsonschema)
cd config/pi
python3 -c "
import json, re
from jsonschema import validate
schema = json.load(open('settings-schema.json'))
raw = open('settings.jsonc').read()
lines = [l for l in raw.split('\n') if not l.strip().startswith('//')]
clean = re.sub(r',(\s*[}\]])', r'\1', '\n'.join(lines))
validate(json.loads(clean), schema)
print('✓ Valid')
"
```

## Updating the Schema

Schema was generated from `settings-manager.d.ts` in the pi package:

```
~/.bun/install/global/node_modules/@mariozechner/pi-coding-agent/dist/core/settings-manager.d.ts
```

If pi adds new settings, update `settings-schema.json` to match the `Settings` interface.
