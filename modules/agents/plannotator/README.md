---
purpose: Own the pinned Plannotator binary and supported agent integrations.
applies_to: Claude, Pi, OMP, or Herdr hosts using Plannotator, plus Codex cleanup.
entrypoint: modules/agents/plannotator/default.nix
verification: Rebuild, then check the binary, hooks, plugin, and Pi packages.
update_when: Plannotator releases or supported agent integration contracts change.
---

# Plannotator

The module enables itself when Claude, Pi, OMP, or Herdr is enabled. It installs
one pinned binary and uses upstream-native integrations:

- Claude: marketplace plugin.
- Pi and OMP: pinned `@plannotator/pi-extension`.
- Herdr: the shared binary and integrations inherited by launched agents.

Codex does not expose Plannotator skills or hooks. Its activation removes stale
Plannotator commands from `~/.codex/hooks.json` while preserving other hooks.

Herdr is a workspace owner, not a Plannotator agent harness. Upstream does not
publish a native Herdr adapter.
