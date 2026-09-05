# Claude module

`modules.agents.claude.enable` installs the CLI, `config/agents/core.md` as
`~/.claude/CLAUDE.md`, and shared modes as `~/.claude/agents/`.

Settings are a writable bootstrap from `config/claude/settings.json`, preserving
Herdr/runtime hooks. Plugins are user-installed; `config/claude/plugins/` holds
sources only. WakaTime is Darwin-only and uses `wakatime-api-key`.

Claude gets only `test-quality`, `github-cli-media`, and `lore` links into the
canonical `~/.agents/skills` tree. Other Claude skill copies are removed because
OMP scans both locations; the full catalog must not be duplicated there.
`skills/flake.nix` selects the Lore source; the other two come from `skills/catalog/`.
