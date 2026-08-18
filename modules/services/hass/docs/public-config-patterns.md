---
purpose: Give agents reproducible GitHub searches and vetted public examples for Nix-managed Home Assistant configuration.
applies_to: Researching or designing changes under modules/services/hass.
entrypoint: Run the searches below, then compare candidates with local AGENTS.md and official documentation.
verification: Re-run searches, open pinned sources, and validate adopted changes with the focused HA checks.
update_when: Search syntax, representative sources, or the local Home Assistant architecture changes.
---

# Public Home Assistant configuration patterns

Last researched: 2026-08-17.

Use this as a pattern catalog, not as authority. A public configuration proves
that someone tried a design; it does not prove that the design is current,
secure, or compatible with this deployment. Confirm Home Assistant behavior in
the [official documentation](https://www.home-assistant.io/docs/) and NixOS
behavior in the
[Nixpkgs module](https://github.com/NixOS/nixpkgs/blob/991eb3e01305e9549d0fc5504d034359ae0897a3/nixos/modules/services/home-automation/home-assistant.nix)
before adopting it.

## Reproduce the search

Authenticate `gh`, run narrow structural queries, and inspect the first 50
results rather than copying from a general web search:

```bash
gh search code 'services.home-assistant.config language:Nix' \
  --limit 50 --json repository,path,url
gh search code 'services.home-assistant.config.automation language:Nix' \
  --limit 50 --json repository,path,url
gh search code 'home-assistant extraComponents language:Nix' \
  --limit 50 --json repository,path,url
gh search code 'buildHomeAssistantComponent language:Nix' \
  --limit 50 --json repository,path,url
gh search code 'services.home-assistant customComponents language:Nix' \
  --limit 50 --json repository,path,url
```

Add a concrete integration, service, or behavior to the query when researching
a change. Preserve the result URL or pin the source to a commit; a link to a
moving branch is weak evidence.

## Patterns worth borrowing

| Pattern                                              | Representative source                                                                                                                                                                                                                                                                                                                                                   | Why it fits here                                                                                                                                 | Reject when                                                                                                                        |
| ---------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------ | ---------------------------------------------------------------------------------------------------------------------------------- |
| Split behavior by domain or concern                  | [p3t33 automation module](https://github.com/p3t33/nixos_flake/blob/c0f827a3482786ec597ac20055f381054058606f/modules/nixos/services/home-assistant/automations.nix), [THERAAB battery notifications](https://github.com/THERAAB/nix-homelab/blob/e2464b6f338d4e8cfcc8f2f73b83f212210d0133/systems/x86_64-linux/nix-hypervisor/home-assistant/battery-notifications.nix) | Matches `_domains/`: keep entities, helpers, scripts, and automations for one capability close enough to review together.                        | The split creates a pass-through module or scatters one behavior across unrelated files.                                           |
| Declare integration dependencies in Nix              | [Nixpkgs dependency resolution](https://github.com/NixOS/nixpkgs/blob/991eb3e01305e9549d0fc5504d034359ae0897a3/nixos/modules/services/home-automation/home-assistant.nix#L83-L134), [oddlama deployment](https://github.com/oddlama/nix-config/blob/7dcf5e493741fb5bbedde92a64dc8ea697718dd7/hosts/sausebiene/home-assistant.nix#L32-L82)                               | `extraComponents`, `customComponents`, and `extraPackages` make runtime dependencies part of the build instead of an installation-time surprise. | The integration is UI-only, already supplied by `default_config`, or the package is added without evidence that HA imports it.     |
| Package custom integrations reproducibly             | [Nixpkgs custom-component option](https://github.com/NixOS/nixpkgs/blob/991eb3e01305e9549d0fc5504d034359ae0897a3/nixos/modules/services/home-automation/home-assistant.nix#L439-L456), [Nixpkgs component packages](https://github.com/NixOS/nixpkgs/tree/991eb3e01305e9549d0fc5504d034359ae0897a3/pkgs/servers/home-assistant/custom-components)                       | Mirrors this module's `buildHomeAssistantComponent` packages and keeps versions and hashes reviewable.                                           | The component is unmaintained, requires mutable self-updates, or duplicates a supported core integration.                          |
| Keep secrets and mutable state outside the Nix store | [oddlama credential materialization](https://github.com/oddlama/nix-config/blob/7dcf5e493741fb5bbedde92a64dc8ea697718dd7/hosts/sausebiene/home-assistant.nix#L143-L171), [Self Host Blocks secret boundary](https://github.com/ibizaman/selfhostblocks/blob/f0b00d57bf6e50a6bd950b206c51b7b859258e30/modules/services/home-assistant.nix#L14-L21)                       | Reinforces the local boundary: declarative behavior belongs in Nix; credentials, registries, pairings, and UI-owned state do not.                | A proposal places plaintext credentials in Nix, commits `.storage`, or assumes state can be reconstructed without a tested backup. |
| Treat state backup as part of the service            | [oddlama persistent config directory](https://github.com/oddlama/nix-config/blob/7dcf5e493741fb5bbedde92a64dc8ea697718dd7/hosts/sausebiene/home-assistant.nix#L17-L24), [Self Host Blocks backup contract](https://github.com/ibizaman/selfhostblocks/blob/f0b00d57bf6e50a6bd950b206c51b7b859258e30/modules/services/home-assistant.nix#L204-L217)                      | Complements this module's documented `/var/lib/hass` restic boundary and prevents declarative rebuilds from being mistaken for full recovery.    | The example backs up only generated YAML while omitting `.storage`, external databases, or device-controller state.                |

The official
[configuration-splitting guide](https://www.home-assistant.io/docs/configuration/splitting_configuration/)
supports focused files and labeled top-level sections. The official
[automation YAML reference](https://www.home-assistant.io/docs/automation/yaml/)
is the authority for automation schema and concurrency modes. The official
[backup integration](https://www.home-assistant.io/integrations/backup/) is the
authority for HA-managed backups; it does not replace checking this host's
restic and PostgreSQL coverage.

## Evaluate a candidate

1. Check the file's latest commit date and the HA/Nixpkgs revision it targets.
2. Prefer a pattern repeated in at least two maintained repositories or backed
   by official documentation.
3. Trace secret, mutable-state, generated-config, and database boundaries.
4. Translate the idea into this module's existing `_domains/` and test
   conventions; do not copy entity IDs, device IDs, service names, or secrets.
5. Verify the generated HA configuration and focused evaluation tests. For a
   deployed behavior change, also read back live state and exercise the path.

## Refresh this guide

Re-run the searches, inspect current source rather than snippets, and replace
representative links only when a newer example improves a documented pattern.
Record the research date. Keep this page small: searches should discover the
ecosystem; this guide should preserve only durable decisions for this module.
