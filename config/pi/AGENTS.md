# Pi sources

`settings.jsonc` owns shared Pi settings/package defaults; the module strips
JSONC and renders `~/.pi/agent/settings.json`. Extensions, prompts, subagents,
keybindings, permissions, and aliases belong here. Module-dependent package
injection belongs in `modules/agents/pi/`; binary pins belong in `overlays/pi/`.

Shared skills use the catalog. Package `skills` arrays remain empty unless a
Pi-native skill resource is needed. Settings check:
`bash modules/agents/pi/test-settings-json.sh`.
