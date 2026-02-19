# Home Assistant Module

NixOS module for Home Assistant with Matter, PostgreSQL recorder, Homebridge, and Tailscale access.

## Backups

HA state lives in `/var/lib/hass` and is backed up nightly by restic (see `hosts/nuc/backups.nix`).

### What's Backed Up

| Data                                           | Location                                 | Recoverable from Nix?                                                                  |
| ---------------------------------------------- | ---------------------------------------- | -------------------------------------------------------------------------------------- |
| Device pairings (Zigbee, BLE, Matter, HomeKit) | `/var/lib/hass/.storage/`                | ❌ No — must restore from backup                                                       |
| Integration configs (API keys, tokens)         | `/var/lib/hass/.storage/`                | ❌ No                                                                                  |
| Entity/device registry (names, areas, IDs)     | `/var/lib/hass/.storage/core.*_registry` | Partial — `devices.yaml` + `apply-devices.py` can reassign areas                       |
| Automations (UI-created)                       | `/var/lib/hass/automations.yaml`         | ❌ No                                                                                  |
| Automations (Nix-declared)                     | `_domains/*.nix`                         | ✅ Yes — rebuilt from Nix                                                              |
| HA config (http, recorder, helpers)            | `default.nix`                            | ✅ Yes — rebuilt from Nix                                                              |
| Extra components (ecobee, cast, etc.)          | `default.nix`                            | ✅ Yes — rebuilt from Nix                                                              |
| Recorder history (energy, temps, states)       | PostgreSQL (`hass` db)                   | ❌ Not in restic — separate pg backup needed                                           |
| HACS integrations                              | `/var/lib/hass/custom_components/`       | Partial — HACS itself is Nix-managed, but HACS-installed integrations need re-download |
| Blueprints (Nix-managed)                       | `blueprints/`                            | ✅ Yes                                                                                 |
| Lovelace dashboards                            | `/var/lib/hass/.storage/lovelace*`       | ❌ No                                                                                  |

### Backup Schedule

- **Frequency:** Daily at midnight
- **Retention:** 7 daily, 5 weekly, 12 monthly
- **Monitoring:** [Healthchecks.io](https://healthchecks.io) ping on start/finish
- **Excludes:** `.stversions`, `.git`

### Recovery Procedure

1. **Restore `/var/lib/hass` from restic:**

   ```bash
   # List snapshots
   sudo restic snapshots --compact

   # Restore latest
   sudo restic restore latest --target / --include /var/lib/hass

   # Or restore a specific snapshot
   sudo restic restore <snapshot-id> --target / --include /var/lib/hass
   ```

2. **Rebuild NixOS** (restores Nix-managed config):

   ```bash
   hey nuc
   ```

3. **Reapply device areas** (if registries were reset):
   ```bash
   ssh nuc "sudo python3 /var/lib/hass/apply-devices.py /var/lib/hass/devices.yaml"
   ```

### What Can't Be Recovered

If backups are lost AND HA storage is gone, you'd need to:

- Re-pair all Zigbee/BLE/Matter/HomeKit devices manually
- Re-authenticate all cloud integrations (ecobee, Spotify, etc.)
- Recreate Lovelace dashboards
- Re-download HACS community integrations

The Nix config rebuilds everything else: components, input helpers, scenes, scripts, blueprints, and Nix-declared automations.

### ⚠️ Gap: PostgreSQL

The recorder database (sensor history, energy data) is in PostgreSQL, **not** in `/var/lib/hass`. It's not currently backed up by restic. This is acceptable if history is non-critical, but add a `pg_dump` pre-backup hook if you want it preserved.

## Declarative Device Management

`devices.yaml` maps devices to areas. `apply-devices.py` applies these via the HA WebSocket API:

```bash
# Run manually
ssh nuc "sudo python3 /var/lib/hass/apply-devices.py /var/lib/hass/devices.yaml"
```

The script is idempotent — it creates missing areas and only updates devices whose area differs. It also runs automatically as a systemd oneshot after HA starts (`hass-apply-devices.service`).

## Module Options

```nix
modules.services.hass = {
  enable = true;
  extraComponents = [ "spotify" "cast" ];  # Additional HA integrations
  postgres.enable = true;                   # PostgreSQL recorder backend
  matter.enable = true;                     # Matter/Thread support
  homebridge.enable = true;                 # Homebridge for HomeKit
  tailscaleService.enable = true;           # HTTPS via Tailscale
};
```
