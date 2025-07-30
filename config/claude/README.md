# MCP Servers

```sh
claude mcp add-json -s user github '{"command":"docker","args":["run","-i","--rm","-e","GITHUB_PERSONAL_ACCESS_TOKEN","ghcr.io/github/github-mcp-server"],"env": {"GITHUB_PERSONAL_ACCESS_TOKEN":"$(op read \"op://Private/GitHub Personal Access Token/token\")"}}'
```
