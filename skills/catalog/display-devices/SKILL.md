---
name: display-devices
description: Use when inspecting, previewing, drawing, messaging, capturing, publishing, or diagnosing the BUSY Bar or TRMNL OG/X displays from the declarative dotfiles configuration.
---

# Display devices

Use this skill for display work in the dotfiles repository. Keep the device
inventory and behavior in version control, and use `displayctl` as the single
agent-facing boundary. Do not send ad-hoc HTTP requests when the CLI supports
the operation.

## Discover and diagnose

Start with the public inventory and live checks:

```sh
displayctl inventory --json
displayctl doctor --json
```

For BUSY, inspect the user-visible frame with a read-only capture:

```sh
displayctl busy-bar capture --target usb --display 0 --output /tmp/busy-front.png
```

For TRMNL, use `displayctl trmnl-og devices`, `displayctl trmnl-og current`,
or the corresponding `trmnl-x` command. A webhook response only proves that
the service accepted data; TRMNL devices pull rendered images later. Confirm
the result with current-screen data, device telemetry, or an authorized TRMNL
MCP screenshot after allowing for the device poll.

Keep account/plugin/device IDs, webhook URLs, and tokens out of prose,
committed files, fixtures, and ordinary logs. Device network addresses belong
only in the declarative inventory. Credential values may come only from the
runtime environment or a 1Password-backed secret source.

## Preview, then apply

BUSY draws, messages, clears, and TRMNL webhook messages are previews by
default. Review the JSON request and use `--apply` for the actual remote write;
`--dry-run` is an explicit spelling of the preview mode. Never infer write
authority from a successful validation or a HTTP response alone.

BUSY-specific invariants:

- Put every agent-owned draw in an explicit application namespace such as
  `agent_*`; preserve the existing household namespaces.
- Keep agent priority at or below 50. Do not use an agent overlay to outrank
  the device's built-in or household display sessions.
- Give transient messages a bounded API-supported element lifetime/TTL. If a
  manifest cannot express a bounded lifetime, stop and report that instead of
  leaving an agent message indefinitely active.
- Clear only a named application namespace with
  `displayctl busy-bar clear --application NAME`; never issue an unscoped
  clear. Capture the frame after an applied draw or clear when visual proof is
  required.

TRMNL-specific invariants:

- Send messages through the configured private-plugin webhook with
  `displayctl`; honor the documented webhook rate limit (12 requests/hour on
  the normal plan, 30 requests/hour on TRMNL+). Coalesce or preview updates
  instead of retrying until the limit is exhausted.
- Treat TRMNL as a pull display. Publishing data, receiving HTTP 2xx, or seeing
  a plugin update is not a user-visible proof; re-read the current display or
  device telemetry, or use the plugin's authorized MCP screenshot.
- Before a plugin publish, verify the account and intended settings target in
  the TRMNL UI/API. Do not invent an ID or create a duplicate plugin. Re-read
  the server-side settings after the write.

## Edit and preview TRMNLP

Route source edits to `config/trmnl/agent-message`. Use the pinned rendering
environment before publishing:

```sh
nix develop .#display-devices
cd config/trmnl/agent-message
./test_project.sh
./bin/trmnlp lint
./bin/trmnlp build
```

Use the checked-in fixture for local preview data. Keep plugin IDs, webhook
secrets, and account-specific values external. The project publish guard is
intentional; do not bypass it to create an unknown remote target.

## Handoff contract

End every display task with a machine-readable envelope (JSON or YAML) that
separates preview from applied state:

```yaml
status: success | preview | failure | blocked
operation: inspect | diagnose | draw | message | capture | publish
target: busy-bar | trmnl-og | trmnl-x
applied: true | false
changed_paths: []
verification: []
landing_state: local | rendered | live-readback | blocked
next_action: "one bounded action, or none"
```

For `applied: true`, `verification` must name the authoritative BUSY capture
or TRMNL current-screen/telemetry/MCP evidence. For a preview, say that no
remote state changed. If credentials, account target, rendering dependencies,
or readback are unavailable, return `blocked` or `failure` with the exact safe
recovery action; do not claim completion.
