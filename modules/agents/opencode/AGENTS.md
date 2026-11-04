# OpenCode module

The module installs OpenCode V2 as `opencode` and manages config, core
instructions, agents, and commands under `~/.config/opencode/`. Global
instructions come from `config/agents/core.md`; sources are in
`config/opencode/`.

Shared skills use `~/.agents/skills`; targeted skills use
`~/.config/opencode/skills`. Plugin caches under `~/.cache/opencode` remain
runtime-owned.

`opencode.jsonc` is a writable bootstrap, not a read-only managed file.
The host catalog `modules.agents.mcp` reconciles its `mcp.servers` registrations,
preserving unrelated settings, servers, and runtime-owned authentication.
See [ADR 0013](../../../docs/adr/0013-host-owned-agent-mcp.md) for ownership.
Focused adapter check:
`uv run --with json5 --with tomlkit python -m unittest tests.test_agent_mcp`.

For confirmed plugin-cache corruption, the guarded repair is
`hey opencode-update`, followed by restart. A tarball 404 can instead indicate
registry propagation; check availability before clearing caches.

Run `hey check modules/agents/opencode config/opencode` for managed OpenCode wiring.
Cache repair and restart change live state and require a confirmed runtime fault;
they are not routine verification steps.
