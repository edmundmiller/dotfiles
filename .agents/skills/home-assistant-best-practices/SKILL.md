---
name: home-assistant-best-practices
description: Selects Home Assistant automation, helper, device-control, and dashboard patterns. Use for HA configuration design, refactoring, or AppDaemon apps.
metadata:
  version: 12
---

# Home Assistant patterns

Prefer native conditions/helpers when they express the intended behavior.
Templates remain appropriate for logic native constructs cannot represent.
In this repository, Nix owns declarative HA config; UI/config-flow APIs own
UI-managed integrations. The generic references below do not transfer that
ownership or authorize live changes.

## Safety and semantics

- Verify live entity/device identity when a change depends on it; filter reads
  to relevant fields. If HA is unreachable, continue source-only work where
  possible and identify what remains unverified rather than inventing IDs.
- Entity renames affect dashboards, scripts, scenes, and config-entry membership;
  registry renames do not update every consumer. Use supported APIs, not direct
  `.storage` edits.
- A `wait_for_trigger` awaits a future change; a `wait_template` can complete
  immediately if already true. They are not interchangeable optimizations.
- Scenes assert desired state; scripts perform sequences. Choose automation mode
  for retrigger semantics (restart, queued, parallel, single), not one global rule.
- Prefer stable entity IDs; ZHA remotes use `device_ieee` events, while Z2M
  autodiscovered device triggers are supported exceptions.

## Select a reference

- Entity/helper migration: [safe refactoring](references/safe-refactoring.md).
- Triggers, waits, modes, and actions: [automation patterns](references/automation-patterns.md).
- Helper vs template: [helper selection](references/helper-selection.md) and
  [template guidelines](references/template-guidelines.md).
- YAML-only integrations: [configuration](references/yaml-only-integrations.md).
- Lights, vacuums, Zigbee buttons: [device control](references/device-control.md).
- State snapshots/restoration: [scenes](references/scenes.md).
- Lovelace layout: [dashboard guide](references/dashboard-guide.md);
  individual components: [cards](references/dashboard-cards.md).
- Integration/service lookup: [domain docs](references/domain-docs.md).
- Compound patterns: [examples](references/examples.yaml).
- Python lifecycle/timers: [AppDaemon](references/appdaemon.md).
