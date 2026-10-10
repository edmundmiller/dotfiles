---
purpose: Own the pinned Plannotator binary and supported agent integrations.
applies_to: Claude, Pi, OMP, or Herdr hosts using Plannotator, plus Codex cleanup.
entrypoint: modules/agents/plannotator/default.nix
verification: Rebuild, then check the binary, hooks, plugin, and Pi packages.
update_when: Plannotator releases or supported agent integration contracts change.
---

# Plannotator

The module enables itself when Pi, OMP, or Herdr is enabled. It installs
one pinned binary and uses upstream-native integrations:

- Pi and OMP: pinned `@plannotator/pi-extension`.
- Herdr: the shared binary and integrations inherited by launched agents.

Codex does not expose Plannotator skills or hooks. Its activation removes stale
Plannotator commands from `~/.codex/hooks.json` while preserving other hooks.

Herdr is a workspace owner, not a Plannotator agent harness. Upstream does not
publish a native Herdr adapter.

## Inbox

The module exports `PLANNOTATOR_INBOX_TOOL=1`. Pi and OMP load Plannotator
at session start so the Inbox tool and reply delivery are available before
any review command runs. Without that opt-in, the registrars remain lazy.

After activation with `hey re`, open a fresh shell and run `plannotator inbox`
once. This creates `~/.plannotator/inbox/inbox.json`, which upstream requires
before registering `plannotator_inbox`. Start a fresh interactive Pi or OMP
session afterward. Sending an Inbox message starts a stopped Inbox automatically;
replies arrive when the agent is idle. `plannotator inbox` reopens the window.

The Inbox stays on loopback. Tailscale publication is a separate user choice.
Codex hook cleanup remains unchanged; it has no native Inbox integration here.
