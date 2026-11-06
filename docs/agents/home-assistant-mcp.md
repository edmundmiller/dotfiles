---
purpose: Configure and verify project-local Home Assistant MCP access in Pi.
applies_to: Pi sessions in the dotfiles repository.
entrypoint: .pi/mcp.json
verification: Run pi mcp list --json and inspect the homeassistant entry.
update_when: Home Assistant OAuth requirements or Pi MCP configuration changes.
---

# Home Assistant MCP in Pi

[`.pi/mcp.json`](../../.pi/mcp.json) registers Home Assistant only for this
project. It preserves the existing NixOS MCP server and does not enable HA in
the shared host catalog. Pi must trust the project to load its configuration.
No host rebuild is needed for changes to this file.

## Authentication

The server uses OAuth, not an `op read` command or a stored bearer token in
Git. Pi keeps OAuth credentials in `~/.pi/agent/mcp-auth.json` and refreshes
access tokens. Do not copy that file or browser callback URLs into the repo,
logs, or issue reports. Revoked or expired refresh credentials require sign-in
again.

The explicit client ID is `http://127.0.0.1:8765/`; the callback is
`http://127.0.0.1:8765/callback`. Keep their scheme, host, and port aligned.
Home Assistant accepts URL client identifiers with same-origin redirects.
The callback listener runs on the machine running Pi, not the HA server.

Do not replace these settings with dynamic registration or forced
`clientRegistration: "cimd"` without retesting. During setup, dynamic
registration failed because HA did not support it. Forced CIMD also failed
Pi's public-client metadata check despite HA advertising document support.
The explicit client ID avoids both discovery paths.

## Sign in and verify

In Pi, run these commands separately:

```text
/reload
/mcp login homeassistant
```

Complete HA authorization in the browser while Pi's callback listener is
running. Alternatively, from this checkout:

```sh
pi mcp login homeassistant --local --timeout 300
```

If authorization times out, start a fresh sign-in rather than reuse the old
browser URL. If port 8765 is occupied, finish or stop the earlier sign-in
before retrying. For a browser on another machine, use Pi's interactive
redirect-URL prompt without sharing the URL in chat.

Verify with a fresh process:

```sh
pi mcp list --json | jq '.servers[] | select(.name == "homeassistant") | {name, scope, state, toolCount: (.tools | length), resources}'
```

Expect `scope: "project"` and `state: "connected"`. Other servers needing
authentication, such as Amp, can make the overall list command exit nonzero;
inspect the HA entry separately.

Verification on 2026-11-06 found HA connected with 43 tools and resources.
This proves authentication and discovery, not every tool's behavior or a
future token refresh. No device-control tool was invoked. HA exposes tools
that change devices and household state; connection does not authorize their
use.

## References

- [Home Assistant authentication API](https://developers.home-assistant.io/docs/auth_api/)
- [Host-owned MCP catalog](../adr/0013-host-owned-agent-mcp.md)
- Installed Pi documentation, `docs/mcp.md`, for OAuth and project configuration.
