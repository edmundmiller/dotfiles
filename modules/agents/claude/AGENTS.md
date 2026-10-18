# Claude module

`modules.agents.claude.enable` installs the CLI, `config/agents/core.md` as
`~/.claude/CLAUDE.md`, and shared modes as `~/.claude/agents/`.

Settings are a writable bootstrap from `config/claude/settings.json`, preserving
Herdr/runtime hooks. Pstack uses the child flake's pinned input as a local
`cursor-plugins` marketplace. Do not restore retired DuckDB, Plannotator, or WakaTime plugins.
See [pstack integration](../../../docs/agents/pstack.md) for usage and pin updates.

Claude gets only `test-quality`, `github-cli-media`, `lore`, and `pe-verify`
links into the canonical `~/.agents/skills` tree. Other Claude skill copies are
removed because OMP scans both locations; the full catalog must not be duplicated
there. `skills/flake.nix` selects the Lore and pe-verify sources; the other two
come from `skills/catalog/`.

Run `python3 -m unittest tests.test_agent_instruction_wiring` and
`hey check modules/agents/claude config/claude` for bootstrap or skill-link
changes. A live writable settings file is not source-of-truth evidence.
