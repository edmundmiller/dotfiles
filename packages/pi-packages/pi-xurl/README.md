# pi-xurl

Cross-agent thread reader. Resolve `agents://` URIs for Amp, Codex, Claude, Gemini, Pi, and OpenCode.

## Install

```bash
pi install npm:pi-xurl
```

Requires [`@xuanwo/xurl`](https://github.com/Xuanwo/xurl) (invoked via `npx`).

## Tool: `xurl`

Resolve and read AI agent thread content by URI.

```
agents://codex/019c871c-b1f9-7f60-9c4f-87ed09f13592
agents://claude/2823d1df-720a-4c31-ac55-ae8ba726721f
pi://12cb4c19-2774-4de4-a0d0-9fa32fbae29f
```

Parameters:

- `uri` (required) — thread URI
- `raw` — output raw JSON instead of markdown
- `list` — list subagents/entries for discovery

## Command: `/xurl`

```
/xurl <uri> [--raw] [--list]
```

Shows short output inline, suggests tool for longer results.
