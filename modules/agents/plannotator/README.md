---
purpose: Own the pinned Plannotator binary and supported agent integrations.
applies_to: Claude, Pi, or Herdr hosts using Plannotator, plus Codex cleanup.
entrypoint: modules/agents/plannotator/default.nix
verification: Rebuild, then check the binary, hooks, plugin, and Pi packages.
update_when: Plannotator releases or supported agent integration contracts change.
---

# Plannotator

The module enables itself when Pi or Herdr is enabled. It installs
one pinned binary and uses upstream-native integrations:

- Pi: pinned `@plannotator/pi-extension`.
- Other MCP agents: `plannotator-inbox` stdio server, when a host enables it.
- Herdr: the shared binary and integrations inherited by launched agents.
- Amp on MacTraitor-Pro and NUC: local stdio `plannotator inbox mcp`, enabled
  in each host's MCP configuration. No plan hook or automatic reply wake.

Codex does not expose Plannotator skills or hooks. Its activation removes stale
Plannotator commands from `~/.codex/hooks.json` while preserving other hooks.

Herdr is a workspace owner, not a Plannotator agent harness. Upstream does not
publish a native Herdr adapter.

## Inbox

The module exports `PLANNOTATOR_INBOX_TOOL=1`. Pi loads Plannotator
at session start so the Inbox tool and reply delivery are available before
any review command runs. Without that opt-in, the registrars remain lazy.

After activation with `hey re`, open a fresh shell and run `plannotator inbox`
once. This creates `~/.plannotator/inbox/inbox.json`, which upstream requires
before registering `plannotator_inbox`. Start a fresh interactive Pi
session afterward. Sending an Inbox message starts a stopped Inbox automatically;
replies arrive when the agent is idle. `plannotator inbox` reopens the window.

The module disables upstream's automatic agent connection and instruction-note
installation so opening the Inbox cannot reinstall Codex hooks or replace
host-managed MCP settings. Nix owns binary and extension updates.

## NUC and Tailscale

`modules.services.plannotator` runs `plannotator-inbox.service` as `emiller`,
with the same `~/.plannotator` state used by NUC Pi and Amp sessions. It starts
at boot without a browser and uses upstream's `PLANNOTATOR_INBOX_TAILSCALE=1`.
The NUC is tagged, so `inboxTailscaleAllow` explicitly permits only
`edmundmiller@github`. Startup merges that field into the existing config without
replacing other settings. No LAN port, Funnel, or unrestricted reverse proxy is
added. The existing Tailscale operator is `emiller`.

After an authorized `hey nuc` deployment, check the service and read only the
published address and error, not the registry's tokens:

```bash
ssh nuc 'hostname; uname -a; test "$(hostname)" = nuc'
ssh nuc 'systemctl status plannotator-inbox.service --no-pager'
ssh nuc 'jq ".tailscale | {url, error}" ~/.plannotator/inbox/inbox.json'
```

The address is `https://nuc.cinnamon-rooster.ts.net:<inbox-port>/`; upstream
persists the port and removes its own Serve mapping on a clean stop. Open that
address from an untagged device signed in as the allowed login. The tailnet
listener refuses MCP, bridge, and control endpoints. Restart Pi sessions after
the upgrade to load the new extension. Restart Amp to load the local MCP server.

MacTraitor-Pro and Seqeratop still use their own local Inbox and local MCP
process. There is no global NUC endpoint or automatic machine pairing.
Seqeratop must remain unlinked from the NUC. If a combined personal view is
wanted, pair only MacTraitor-Pro with NUC through Settings → Machines after
deployment. Threads remain on the machine that owns their agent.

## Grok Bot pairing

The pinned 0.28.66 supports Grok Bot's cloud-agent relay. In the NUC Inbox,
open Settings → Cloud agents, pair Grok Bot, and send the one-time pairing
message to Grok Bot. Keep pairing material out of this repository and logs.
Add the routine's POST wake address and key in the same settings, then test
the wake. In Grok Bot, allow `plannotator inbox call` for that routine. Without
a webhook, Grok Bot can check on its own schedule instead.

Pairing and the routine's approval rule require the owner's interactive setup.
The NUC must stay online. Grok Bot reads only assigned threads, and Inbox file
attachments do not reach it. This pairing does not connect Seqeratop.

To remove NUC hosting, disable `modules.services.plannotator.enable` and deploy.
The clean stop removes its Serve mapping but retains Inbox data and pairings.
Codex hook cleanup remains unchanged; it has no Inbox integration here.
