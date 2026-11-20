# HA Entity Lifecycle & Storage

## How HA Stores Entities

HA has two distinct stores for entity information:

### 1. Configuration (YAML/DB)

The source of truth for _what should exist_:

- **YAML-declared** (`configuration.yaml` via Nix): Read on startup. HA
  creates entities for each `automation:`, `scene:`, `script:` entry.
  Read-only — HA can't edit these. Removing from YAML removes from config
  but may leave orphans in the entity registry.

- **UI-created** (`automations.yaml`, `scenes.yaml`, `scripts.yaml`):
  Read/written by HA's config API endpoints. The `"automation ui":
"!include automations.yaml"` lines in `configuration.yaml` load these.

### 2. Entity Registry (`.storage/core.entity_registry`)

A JSON file tracking all known entities with metadata:

- `entity_id` — the `domain.object_id` identifier
- `unique_id` — platform-specific identifier (automation `id` field, scene UUID, script key)
- `platform` — which integration created it (`automation`, `homeassistant`, `script`, `ecobee`, etc.)
- `disabled_by`, `hidden_by`, `name`, `icon` overrides

**This is where ghosts live.** When a YAML automation is removed, HA may
not clean up its entity registry entry. The entity shows as "unavailable"
but persists across restarts.

## Ghost Entity Problem

Ghosts appear when:

1. An automation/scene/script was in Nix config, deployed, then removed
2. Someone creates via UI, it gets registered, then the UI file is wiped
3. HA creates entities from integrations that later get removed

The entity registry is append-mostly — HA is conservative about removal.

## What the Sweep Does

The sweep service (`hass-sweep-unmanaged`) solves this by:

1. Reading the build-time manifest of declared entity identifiers
2. Querying the live entity registry via WebSocket
3. Removing any automation/scene/script entity not in the manifest
4. Filtering by `platform` to only touch YAML-sourced entities

## WebSocket Commands Used

```
config/entity_registry/list    → returns all registered entities
config/entity_registry/remove  → removes entity by entity_id
```

These are internal HA WS commands (used by the frontend). They require
admin-level authentication.

## UI YAML Files

| File               | Format | Empty value |
| ------------------ | ------ | ----------- |
| `automations.yaml` | list   | `[]`        |
| `scenes.yaml`      | list   | `[]`        |
| `scripts.yaml`     | dict   | `{}`        |

The sweep wipes these to `[]`/`{}` after removing orphans, preventing
UI-created entities from surviving across deploys.

## Config API Endpoints (Reference)

For manual management of UI-created entities:

```
GET    /api/config/automation/config/{id}    — read
POST   /api/config/automation/config/{id}    — create/update
DELETE /api/config/automation/config/{id}    — delete + registry cleanup

GET    /api/config/scene/config/{id}         — read
POST   /api/config/scene/config/{id}         — create/update
DELETE /api/config/scene/config/{id}         — delete + registry cleanup

GET    /api/config/script/config/{key}       — read
POST   /api/config/script/config/{key}       — create/update
DELETE /api/config/script/config/{key}       — delete + registry cleanup
```

These operate on the UI YAML files only, not the Nix-managed
`configuration.yaml` entries. After delete, the post_write_hook removes
the entity from the entity registry automatically.
