# Pi Config

This directory owns Pi runtime configuration sources.

Use `settings.jsonc` for broad Pi package defaults and Pi settings. The Nix
module strips JSONC and renders it to `~/.pi/agent/settings.json`; never edit
the runtime symlink directly.

Use this directory for Pi extensions, prompt templates, subagents/chains,
keybindings, permission policy, and shell aliases. Keep module-dependent package
injection in `modules/agents/pi/`. Keep Pi binary version/package-lock overrides
in `overlays/pi/`.

Skills are not installed through Pi package `skills` entries here. Shared skills
come from the agent skills catalog; package `skills` arrays should usually be
empty unless the package needs a Pi-native skill resource.

After changing settings or package entries, run:

```sh
bash modules/agents/pi/test-settings-json.sh
```

After changing local TypeScript extensions, run their focused tests when present
and avoid broad workspace checks unless the change crosses package boundaries.
