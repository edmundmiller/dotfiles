# Claude module

`modules.agents.claude.enable` installs the CLI, `config/agents/core.md` as
`~/.claude/CLAUDE.md`, and shared modes as `~/.claude/agents/`.

Settings are a writable bootstrap from `config/claude/settings.json`, preserving
Herdr/runtime hooks and plugin entries that are absent from the template.
Template plugin keys win. Do not restore retired DuckDB, Plannotator, or WakaTime plugins.
The bootstrap drops those entries when an old settings file still has them.
See [pstack integration](../../../docs/agents/pstack.md) for usage and pin updates.

`modules.agents.claude.pstack.enable` defaults to the full module's enable flag.
It can be enabled alone, as on NUC, to merge only pstack settings and link its
marketplace without changing existing permissions, hooks, instructions, or MCP.

`claude-shared-skill-links` in [default.nix](default.nix) selects Claude's links
into the canonical `~/.agents/skills` tree. Other Claude skill copies are
removed because OMP scans both locations; the full catalog must not be duplicated
there. `skills/flake.nix` owns shared skill sources and selection.

Run `python3 -m unittest tests.test_agent_instruction_wiring` and
`hey check modules/agents/claude config/claude` for bootstrap or skill-link
changes. A live writable settings file is not source-of-truth evidence.
