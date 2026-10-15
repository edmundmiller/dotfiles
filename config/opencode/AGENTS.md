# OpenCode V2 sources

`modules/agents/opencode/` seeds writable
`~/.config/opencode2/opencode/opencode.jsonc` from `opencode.jsonc` and manages
`command/` as read-only links. Core instructions and modes come from
`config/agents/`. Shared skills use `~/.agents/skills`; targeted skills use
the compatibility alias `~/.config/opencode/skills`.

The host catalog `modules.agents.mcp` owns `mcp.servers` registrations through
the shared reconciler, preserving unrelated settings and runtime-owned auth.
Edit host registrations in the host configuration, not this bootstrap template.
See [ADR 0013](../../docs/adr/0013-host-owned-agent-mcp.md) for ownership and
`uv run --with json5 --with tomlkit python -m unittest tests.test_agent_mcp`
for the focused adapter check.

The module does not deploy `tool/`, `package.json`, `node_modules/`, or local
plugins. A local plugin needs explicit V2-compatible wiring and registration;
the incompatible V1 plugin tree is not an installation path.

Activation removes the V1 config directory and establishes the V2 compatibility
alias, preserving plugin caches and user-managed content.

Run `hey check config/opencode modules/agents/opencode` for source and deployment
changes. Cache deletion and activation are live repairs, not config validation.
