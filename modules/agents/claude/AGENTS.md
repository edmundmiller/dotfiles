# Claude module

`modules.agents.claude.enable` installs the CLI, `config/agents/core.md` as
`~/.claude/CLAUDE.md`, and shared modes as `~/.claude/agents/`.

Settings are a writable bootstrap from `config/claude/settings.json`, preserving
Herdr/runtime hooks. Pstack uses the child flake's pinned input as a local
`cursor-plugins` marketplace. Do not restore retired DuckDB, Plannotator, or WakaTime plugins.
See [pstack integration](../../../docs/agents/pstack.md) for usage and pin updates.

`modules.agents.claude.pstack.enable` defaults to the full module's enable flag.
It can be enabled alone, as on NUC, to merge only pstack settings and link its
marketplace without changing existing permissions, hooks, instructions, or MCP.

`claude-shared-skill-links` in [default.nix](default.nix) selects Claude's links
into the canonical `~/.agents/skills` tree. Other Claude skill copies are
removed because OMP scans both locations; the full catalog must not be duplicated
there. `skills/flake.nix` owns shared skill sources and selection.

`claude-session-budget-hooks` upserts `config/claude/session-budget-hook.py` into
the live settings on `SessionStart`, `UserPromptSubmit`, and `Stop`. The hook only
warns, never blocks. Generation warnings run on `UserPromptSubmit` and `Stop`
alongside the context check. `SessionStart` resume behavior is unchanged.
Hooks are upserted by command string rather than declared in
the template because the bootstrap keeps the runtime's hook list. Keep any new
hook additive so Herdr, Entire, and plugin hooks survive.

Run `python3 -m unittest tests.test_agent_instruction_wiring` and
`hey check modules/agents/claude config/claude` for bootstrap or skill-link
changes. A live writable settings file is not source-of-truth evidence.
