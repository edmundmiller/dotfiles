# Claude module

`modules.agents.claude.enable` installs the CLI, `config/agents/core.md` as
`~/.claude/CLAUDE.md`, and shared modes as `~/.claude/agents/`.

Settings are a writable bootstrap from `config/claude/settings.json`, preserving
Herdr/runtime hooks. Claude Code plugins, marketplaces, and their WakaTime wiring
are retired; do not restore plugin installation during activation.

Claude gets only `test-quality`, `github-cli-media`, and `lore` links into the
canonical `~/.agents/skills` tree. Other Claude skill copies are removed because
OMP scans both locations; the full catalog must not be duplicated there.
`skills/flake.nix` selects the Lore source; the other two come from `skills/catalog/`.
