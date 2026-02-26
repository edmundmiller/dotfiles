---
name: hass-declarative
description: >
  Manage Home Assistant automations, scenes, and scripts declaratively
  via NixOS modules. Covers adding/editing/removing entities in the
  domain-based Nix structure, the sweep service that cleans orphaned
  entities, entity identity (IDs, slugs, unique_ids), the eval test
  assertions, and the build-time manifest.
  Trigger phrases: "add HA automation", "new scene", "new script",
  "remove automation", "declarative HA", "sweep unmanaged",
  "entity drift", "ghost entity", "orphaned automation",
  "HA domain file", "eval-automations test", "hass assertion".
---

# HA Declarative Entity Management

All HA automations, scenes, and scripts are defined in Nix under
`modules/services/hass/_domains/`. A post-deploy sweep service removes
anything not in the declared set.

## Architecture

```
_domains/                      ← domain files (Nix modules)
  ambient.nix                  ← lighting schedules, plant lights
  aranet.nix                   ← CO2 monitoring
  conversation.nix             ← voice intents
  lighting.nix                 ← adaptive lighting, AL sleep mode
  modes.nix                    ← DND, guest mode, everything_off script
  sleep/default.nix            ← bedtime flow, wake detection, 8Sleep sync
  tv.nix                       ← TV idle timer, sleep timer
  vacation.nix                 ← presence-based vacation mode

sweep-unmanaged.nix            ← extracts declared IDs at build time
sweep-unmanaged.py             ← runtime: removes orphans via WS API
_tests/eval-automations.nix    ← structural assertions (flake check)
```

## Entity Identity

How HA maps Nix config → entity registry:

| Domain     | Nix declaration                  | Entity ID                 | Unique ID (registry)  |
| ---------- | -------------------------------- | ------------------------- | --------------------- |
| automation | `id = "winding_down";`           | `automation.winding_down` | Same as `id` field    |
| scene      | `name = "Good Morning";`         | `scene.good_morning`      | HA-generated UUID     |
| script     | `script.everything_off = {...};` | `script.everything_off`   | Same as attribute key |

Scene slugs: HA lowercases the name and replaces spaces/hyphens with
underscores. Keep names ASCII-alphanumeric + spaces to avoid slug surprises.

## Adding Entities

### Automation

Add to the `automation = lib.mkAfter [...]` list in the appropriate domain file.
Every automation **must** have a unique `id` field — the sweep service uses it.

```nix
{
  alias = "Human-Readable Name";
  id = "unique_snake_case_id";
  description = "What it does";
  trigger = { platform = "time"; at = "22:00:00"; };
  condition = [];
  action = [{ action = "scene.turn_on"; target.entity_id = "scene.foo"; }];
}
```

### Scene

Add to `scene = lib.mkAfter [...]`. Scenes use `name` as their identity.

```nix
{
  name = "My Scene";
  icon = "mdi:icon-name";
  entities = {
    "light.some_light" = "on";
    "switch.some_switch" = "off";
  };
}
```

### Script

Add to `script = lib.mkAfter {...}` (attrset, not list). The attribute
key becomes the entity_id.

```nix
my_script_key = {
  alias = "Human Name";
  icon = "mdi:icon";
  sequence = [{ action = "light.turn_off"; target.entity_id = "light.foo"; }];
};
```

Or directly on config: `script.my_key = {...};` (as in `modes.nix`).

## Removing Entities

1. Delete from the domain `.nix` file
2. Deploy (`hey nuc`)
3. `hass-sweep-unmanaged` service auto-removes the orphan from HA's entity registry

No manual cleanup needed. Check sweep results:

```bash
hey nuc-service hass-sweep-unmanaged
ssh nuc "sudo journalctl -u hass-sweep-unmanaged --no-pager -n 30"
```

## Sweep Service

`sweep-unmanaged.nix` creates a systemd oneshot that runs after HA starts.

**Build time:** Evaluates NixOS config to extract:

- `automation_ids` — from `haConfig.automation[].id`
- `scene_entity_ids` — from `haConfig.scene[].name` → `scene.<slug>`
- `script_entity_ids` — from `haConfig.script` keys → `script.<key>`

Writes these to a JSON manifest in the Nix store.

**Runtime** (`sweep-unmanaged.py`):

1. Waits for HA to be ready (120s timeout)
2. Connects via WebSocket, authenticates with `agent-automation` JWT
3. Lists all entity registry entries
4. For each `automation.*` / `scene.*` / `script.*` not in the manifest:
   - Checks `platform` to avoid removing integration-created entities
   - Removes from entity registry via `config/entity_registry/remove`
5. Wipes UI YAML files (`automations.yaml`, `scenes.yaml`, `scripts.yaml`)

**Platform filtering** (safety):

- Automations: only removes `platform = "automation"` (YAML-sourced)
- Scenes: only removes `platform = "homeassistant"` (YAML-sourced)
- Scripts: only removes `platform = "script"` (YAML-sourced)
- Integration-created entities (Ecobee scenes, etc.) are never touched

## Eval Test Assertions

`_tests/eval-automations.nix` runs as `nix flake check` and pre-commit hook.
Tests structural properties:

- Required automations/scenes exist
- Time guards present on wake detection (the "4:47 AM fix")
- Good Morning has presence-aware conditions
- Winding Down resets awake booleans

Add assertions when adding automations with critical invariants.

## Debugging

```bash
# Check what the sweep would do (dry-run)
ssh nuc "sudo systemctl cat hass-sweep-unmanaged"  # see ExecStart paths
ssh nuc "sudo /path/to/python3 /path/to/sweep-unmanaged.py /path/to/manifest.json --dry-run"

# View the build-time manifest
nix eval --json '.#nixosConfigurations.nuc.config.services.home-assistant.config.automation' 2>/dev/null | python3 -c "import json,sys; print([a['id'] for a in json.load(sys.stdin) if a.get('id')])"

# Run eval assertions locally
nix build '.#checks.x86_64-linux.ha-automation-assertions' --dry-run
```

## References

| File                             | Contents                                                                             |
| -------------------------------- | ------------------------------------------------------------------------------------ |
| `references/entity-lifecycle.md` | How HA stores entities internally, the .storage files, and what "ghost" entities are |
