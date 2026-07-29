---
purpose: Own the pinned Plannotator binary and supported agent integrations.
applies_to: Codex, Claude, Pi, OMP, or Herdr hosts using Plannotator.
entrypoint: modules/agents/plannotator/default.nix
verification: Rebuild, then check the binary, hooks, plugin, and Pi packages.
update_when: Plannotator releases or supported agent integration contracts change.
---

# Plannotator

The module enables itself when Codex, Claude, Pi, OMP, or Herdr is enabled. It
installs one pinned binary and uses upstream-native integrations:

- Codex: merged global `Stop` hook with the Nix-store binary path.
- Claude: marketplace plugin.
- Pi and OMP: pinned `@plannotator/pi-extension`.
- Herdr: the shared binary and integrations inherited by launched agents.

Herdr is a workspace owner, not a Plannotator agent harness. Upstream does not
publish a native Herdr adapter.
