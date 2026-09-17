# Claude module

`modules.agents.claude.enable` installs the CLI, `config/agents/core.md` as
`~/.claude/CLAUDE.md`, and shared modes as `~/.claude/agents/`.

Settings are a writable bootstrap from `config/claude/settings.json`, preserving
Herdr/runtime hooks. The DuckDB plugin is the only generally managed Claude Code
plugin; other retired plugins and their WakaTime wiring must not be restored.

Claude gets only `test-quality`, `github-cli-media`, `lore`, and `pe-verify`
links into the canonical `~/.agents/skills` tree. Other Claude skill copies are
removed because OMP scans both locations; the full catalog must not be duplicated
there. `skills/flake.nix` selects the Lore and pe-verify sources; the other two
come from `skills/catalog/`.
