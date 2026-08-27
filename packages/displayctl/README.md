---
purpose: Give agents a bounded CLI for inspecting local display links and managing external displays.
applies_to: macOS USB-C links, BUSY Bar, TRMNL OG, and TRMNL X on a managed dotfiles host.
entrypoint: Run displayctl inventory --json or displayctl macos status for the local link state.
verification: Run the package contract tests and the relevant read-only status command on the target host.
update_when: Display topology, device addresses, API paths, or credential environment names change.
---

# displayctl

`displayctl` is the small, noninteractive display boundary for agents. It
prints JSON on stdout and diagnostics on stderr. The declarative inventory at
`config.json` contains public addresses, models, capabilities, and credential
environment names. It contains no credential values.

## Read-only discovery

```sh
displayctl inventory --json
displayctl doctor --json
displayctl macos status
displayctl busy-bar capture --target usb --display 0 --output /tmp/busy-front.png
displayctl trmnl-og devices
displayctl trmnl-x current
```

`doctor` checks reachability and reports only whether configured credential
environment variables are present. BUSY checks cover the device targets;
TRMNL checks are one row per capability (`devices`, `current`, and `message`),
so an account key alone does not imply current-screen or webhook readiness.
`capture` reads a BUSY frame and writes a local PNG; it does not change the
device.

### macOS USB-C and DisplayPort links

`displayctl macos status` reads the I/O Registry and Thunderbolt system profile.
It reports each DisplayPort transport, the TS5 host port, and any recognized
link-training or topology issue. It makes no system or hardware changes.

The JSON `state` is `healthy`, `unhealthy`, or `unobserved`; `unobserved` keeps
absent hardware distinct from a verified healthy link. Exit status `0` covers
`healthy` and `unobserved`, `1` means current evidence matches an issue, and `2`
means the diagnostic itself could not run. On `MacTraitor-Pro`, the expected
TS5 port and ordered manual recovery are versioned in `config.json`; the host
runbook owns the physical interpretation.

When `--config` is omitted, the CLI resolves configuration in this order:
`DISPLAYCTL_CONFIG`, an existing `~/.config/displayctl/config.json`, the
installed `$out/share/displayctl/config.json`, then the source-tree sibling
`packages/displayctl/config.json`. This keeps the same declarative inventory
available when an agent runs with a different `HOME`.

## Preview and apply

Every BUSY draw/message/clear and TRMNL webhook message is a dry run by
default. Add `--apply` for the remote write. `--dry-run` is accepted as an
explicit spelling of the default and cannot be combined with `--apply`.

```sh
displayctl busy-bar validate --manifest ./bedtime.json
displayctl busy-bar draw --target lan --manifest ./bedtime.json
displayctl busy-bar draw --target lan --manifest ./bedtime.json --apply
displayctl busy-bar message --text "Agent ready" --apply
displayctl busy-bar clear --application agent_message --apply

displayctl trmnl-og message --text "Agent ready"
displayctl trmnl-og message --text "Agent ready" --apply
displayctl trmnl-x message \
  --headline "Build complete" \
  --text "The checks passed." \
  --source Codex \
  --status Ready \
  --timestamp "2026-08-24 09:30" \
  --progress 100 \
  --apply
```

TRMNL message payloads map directly to the checked-in agent-message template:
`--text` is required and becomes `message`; `--headline`, `--source`,
`--status`, `--timestamp`, and `--progress` are included only when supplied.
Progress must be an integer from 0 through 100. The dry-run/result `payload`
contains only these public fields; the applied private-plugin webhook wraps it
as `{"merge_variables": {...}}`. The template supplies its own visual defaults
for omitted fields.

BUSY clears always require an explicit application namespace; there is no
unscoped clear command. `busy-bar` uses USB by default (`10.0.4.20`) and the
LAN target is selected with `--target lan`.

Agent-owned BUSY applications must use an `application_name` matching
`^[A-Za-z0-9._-]+$`, and their priority is capped at 50 so built-in/shared
sessions remain authoritative. Every draw element must include a positive
integer `timeout` no greater than 3,600 seconds (one hour). The live BUSY API
25.0.0 OpenAPI schema documents `timeout` as an integer with `minimum: 0` and
no upper bound; this client policy keeps agent-owned overlays finite while
remaining within the API's documented range. The CLI does not expose an
unbounded display-until mode.
Every element also needs an `id` matching the same safe pattern. Text elements
need a non-empty `font` (the generated `busy message` uses `normal`), countdowns
need a digits-only string `timestamp`, `direction` of `time_left` or
`time_since`, and `show_hours` of `when_non_zero` or `always`. Rectangles need
positive integer `width` and `height`; images and animations need exactly one
non-empty `path` or `stock_path`. `busy message` adds `id: message` and
`timeout: 75` by default and accepts `--timeout` for a different duration up
to 3,600 seconds.

## Credentials

The runtime supplies values, never this repository:

- BUSY LAN: optional `BUSY_BAR_API_TOKEN` in the current no-key access mode;
  required after the device is switched to key mode.
- TRMNL account API: `TRMNL_API_KEY`.
- TRMNL current-display Access-Token: `TRMNL_OG_DEVICE_API_KEY` or `TRMNL_X_DEVICE_API_KEY`.
- Shared agent-message plugin webhook: `TRMNL_AGENT_MESSAGE_WEBHOOK_URL`.

The CLI does not print these values or include webhook URLs in JSON output.
