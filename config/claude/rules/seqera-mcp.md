## Seqera MCP (updated 2026-11)

- For any Platform lookup or one-off write (Studios, compute environments, labels, workspaces,
  members, runs), use the `platform_*` tools before curl or the OpenAPI spec, even when the tool
  you are building calls the raw API.

- The Seqera MCP (`mcp__seqera__*`) now exposes every tool directly: `platform_*`, `wave_*`, `nextflow_*`,
  `sra_*`, `igenomes_*`, `seqerahub_*`. Load the specific tool with ToolSearch and call it. The old
  search-then-execute step is gone, and no Seqera Claude skill is needed; the guidance is in the MCP server
  description, the same pattern Snowflake uses.
- You can chat with Seqera's co-scientist directly through the MCP.
- If the MCP is failing, use the `tw` CLI when `command -v tw` finds it; otherwise report the MCP failure.
- Source: https://seqera.slack.com/archives/C089B7YM0AK/p1794852145695249
