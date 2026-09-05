# Hermes seed configuration

`modules/agents/hermes/default.nix` merges `config.yml` into writable
`$HERMES_HOME/config.yaml` for the NixOS runtime. Durable defaults belong here,
not in the live file. Reusable runtime/profile logic belongs in `agents-workspace`.

Declare MCP servers under `mcp_servers`. Use `${GITHUB_TOKEN}`-style environment
interpolation for credentials; host `modules.agents.hermes.secretReferences`
maps those names to 1Password references and materializes `$HERMES_HOME/.env`.
The MCP server's expected variable name can differ from the interpolated name.
