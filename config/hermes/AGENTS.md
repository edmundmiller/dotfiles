# Hermes Config

Repo-managed, user-facing Hermes seed files. `config.yml` is merged into writable `$HERMES_HOME/config.yaml` by `modules/agents/hermes/default.nix`; do not edit `$HERMES_HOME/config.yaml` for durable repo defaults.

## MCP servers

Declare safe-to-commit MCP server configuration in `config.yml` under `mcp_servers`. For secrets, use Hermes environment interpolation and host-managed `.env` entries instead of plaintext values.

Example:

```yaml
mcp_servers:
  github:
    command: "npx"
    args: ["-y", "@modelcontextprotocol/server-github"]
    env:
      GITHUB_PERSONAL_ACCESS_TOKEN: "${GITHUB_TOKEN}"
```

Then add `GITHUB_TOKEN = "op://.../credential";` to the enabled host's `modules.agents.hermes.secretReferences` (for the personal laptop, `hosts/mactraitorpro/default.nix`). Activation writes `$HERMES_HOME/.env`; Hermes loads it and resolves `${GITHUB_TOKEN}` before launching the MCP server.

Never commit literal API tokens or PATs here.
