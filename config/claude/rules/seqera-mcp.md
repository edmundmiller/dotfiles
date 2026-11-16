## Seqera MCP (updated 2026-11)

- The Seqera MCP (`mcp__seqera__*`) now exposes every tool directly: `platform_*`, `wave_*`, `nextflow_*`,
  `sra_*`, `igenomes_*`, `seqerahub_*`. Load the specific tool with ToolSearch and call it. The old
  search-then-execute step is gone, and no Seqera Claude skill is needed; the guidance is in the MCP server
  description, the same pattern Snowflake uses.
- You can chat with Seqera's co-scientist directly through the MCP.
- If the MCP is failing, use the `tw` CLI instead.
- Source: https://seqera.slack.com/archives/C089B7YM0AK/p1794852145695249
