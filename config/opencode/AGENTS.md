# OpenCode sources

`modules/agents/opencode/` seeds writable
`~/.config/opencode/opencode.jsonc` from `opencode.jsonc` and manages
`command/` as read-only links. Core instructions and modes come from
`config/agents/`. Shared skills use `~/.agents/skills`; targeted skills use
`~/.config/opencode/skills`.

The host catalog `modules.agents.mcp` owns `mcp.servers` registrations through
the shared reconciler, preserving unrelated settings and runtime-owned auth.
Edit host registrations in the host configuration, not this bootstrap template.
See [ADR 0013](../../docs/adr/0013-host-owned-agent-mcp.md) for ownership and
`uv run --with json5 --with tomlkit python -m unittest tests.test_agent_mcp`
for the focused adapter check.

The module does not deploy `tool/`, `package.json`, `node_modules/`, or local
plugins. Local plugins need explicit wiring and registration.

Run `hey check config/opencode modules/agents/opencode` for source and deployment
changes. Cache deletion and activation are live repairs, not config validation.
