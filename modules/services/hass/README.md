# Home Assistant Module

NixOS module for Home Assistant with Matter, PostgreSQL recorder, Homebridge, and Tailscale access.

## Inspect health and traces

After deployment, `hass-health` provides read-only health checks and trace access.
It never calls services, runs automations, dismisses Repairs, or edits `.storage`.
Supply an existing token with `HASS_TOKEN`, `HASS_TOKEN_FILE`, or `--token-file`.
An explicit token file takes precedence over the environment token. HA requires
administrator access for traces; the command is read-only, but the token itself
is not restricted to read-only operations. Remote connections require HTTPS.

On NUC, use the existing agent token without printing its contents:

```bash
hass-health health --token-file /run/agenix/ha-hermes-token --json
hass-health traces list --domain script --item-id good_morning --token-file /run/agenix/ha-hermes-token --json
hass-health traces get --domain script --item-id good_morning --run-id RUN_ID --token-file /run/agenix/ha-hermes-token --json
```

For automations, use `--domain automation` and the Nix automation `id`, not the
entity ID or display name. `traces list` returns the IDs needed by `traces get`.
Listings are newest-first and default to 20 entries; `--limit` accepts 1 through 100.
Trace commands report `status: ok` when retrieval succeeds, even when the run failed. Inspect
`has_error`, `script_execution`, and the step paths for the run's outcome.

Health reports contain a UTC observation timestamp and these checks:

- Running HA version versus the version embedded in the Nix-built command.
  `--expected-version` overrides that expectation for a candidate upgrade.
- Enabled integrations that are not loaded, plus active, non-dismissed Repairs.
- Availability of both thermostats and the bedtime, goodnight, and morning
  scripts. Repeat `--entity` to replace the default list for one invocation.
- Errors in retained automation and script runs from the last 24 hours.
  `--since-hours` changes that window. No retained runs means `unknown`, not a
  successful automation check. Trigger evaluations that did not fire do not
  count as runs.

Exit codes are `0` for healthy or successful trace retrieval, `1` for observed
health failures, and `2` for incomplete inspection or command errors. A known
failure takes precedence over an unknown check, but every check keeps its own
status. Backups and physical device outcomes appear in `not_checked`; this
command alone is not an upgrade acceptance gate. The disabled HA backup
integration does not establish restic health, and an existing backup Repair is
still reported rather than silently ignored.

Trace output includes run IDs, timestamps, step paths, condition results, and
parent context IDs. It omits configuration, variables, service payloads, user
IDs, and free-form error text. Use HA's trace UI for those sensitive details.
Nix-declared automations default to 20 stored traces. The bedtime, morning, and
climate scripts also retain 20. Explicit automation trace settings take
precedence. Retention is count-based, not a guarantee of 24-hour coverage, and
HA saves traces on graceful shutdown rather than continuously to durable storage.

Before deployment, run the source with `uv run --script
modules/services/hass/hass-health.py` followed by the same subcommands. Supply
`--expected-version` and `--entity` on source health runs because the Nix wrapper
provides those defaults. Run the isolated CLI tests with
`uv run --with websockets==15.0.1 python modules/services/hass/_tests/test_hass_health.py`.
`hey check modules/services/hass` also runs them through Nix.

## FitBark

[FitBark](https://github.com/saubury/ha-fitbark) is Nix-managed. Do not install
a second copy through HACS. After an authorized deployment:

1. Register an application at the [FitBark developer portal](https://www.fitbark.com/dev/)
   to obtain a client ID and client secret.
2. Open **Settings → Devices & services → Add integration → FitBark** in Home
   Assistant, enter the application credentials, and complete the OAuth login.
3. Confirm each dog appears as a device. The integration initially imports
   42 days of activity into recorder statistics.

Keep credentials in Home Assistant's config flow, never in Nix or YAML. The
integration attempts to register `https://my.home-assistant.io/redirect/oauth`
with FitBark automatically. If registration fails, register that redirect with
FitBark before retrying OAuth. The existing `default_config` supplies the required
`application_credentials` and `recorder` integrations.

## Jev (TypeSafe)

[HA-Jev](https://github.com/AboveColin/HA-Jev) and its `jevclient` dependency are
Nix-managed. It requires Home Assistant 2026.9 or newer, supplied by the separate
`nixpkgs-hass` input without upgrading the rest of the host.

After an authorized deployment, go to **Settings → Devices & services → Add
integration → Jev (TypeSafe)** and enter a [TypeSafe](https://typesafe.ai) API key.
Keep the key in the integration's config entry, not in Nix or YAML. Do not install
a second copy through HACS.

The `jev.noul`, `jev.choice`, `jev.score`, and `jev.ask` actions then become
available. No question contexts, polling, or automations are enabled here yet.
Selected state is sent to TypeSafe's cloud API, and requests (including setup
validation) are billable. Set a daily input-token budget in the integration
options before enabling recurring questions. Persistent question contexts belong
in Nix-managed `services.home-assistant.config.jev`; choose real entities and a
specific use case before adding them. Do not use model decisions for
safety-critical controls.

## Backups

HA state lives in `/var/lib/hass` and is backed up nightly by restic (see `hosts/nuc/backups.nix`).

### What's Backed Up

| Data                                           | Location                                                           | Recoverable from Nix?                                                              |
| ---------------------------------------------- | ------------------------------------------------------------------ | ---------------------------------------------------------------------------------- |
| Device pairings (Zigbee, BLE, Matter, HomeKit) | `/var/lib/hass/.storage/`                                          | ❌ No — must restore from backup                                                   |
| Integration configs (API keys, tokens)         | `/var/lib/hass/.storage/`                                          | ❌ No                                                                              |
| Entity/device registry (names, areas, IDs)     | `/var/lib/hass/.storage/core.*_registry`                           | Partial — `devices.yaml` + `apply-devices.py` can reassign areas                   |
| Automations (UI-created)                       | `/var/lib/hass/automations.yaml`                                   | ❌ No                                                                              |
| Automations (Nix-declared)                     | `_domains/*.nix`                                                   | ✅ Yes — rebuilt from Nix                                                          |
| HA config (recorder, helpers)                  | `default.nix`                                                      | ✅ Yes — rebuilt from Nix                                                          |
| HTTP config (port, trusted proxies)            | `/var/lib/hass/.storage/http`                                      | ❌ No — manage under Settings > System > Network; restore from backup              |
| Extra components (ecobee, cast, etc.)          | `default.nix`                                                      | ✅ Yes — rebuilt from Nix                                                          |
| Recorder history (energy, temps, states)       | PostgreSQL (`hass` db), dumped to `/var/backup/hass/recorder.dump` | ❌ No — restore the nightly restic dump                                            |
| Marketplace integrations                       | `/var/lib/hass/custom_components/`                                 | Partial — Marketplace is built in; downloaded integrations may need reinstallation |
| Blueprints (Nix-managed)                       | `blueprints/`                                                      | ✅ Yes                                                                             |
| Lovelace dashboards                            | `/var/lib/hass/.storage/lovelace*`                                 | ❌ No                                                                              |

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

### PostgreSQL recorder backup

The recorder database lives in PostgreSQL, **not** in `/var/lib/hass`. Before each
daily restic backup, `pg_dump --format=custom` takes a consistent online snapshot
using the configured PostgreSQL package and database name. HA stays running.
The root-only dump at `/var/backup/hass/recorder.dump` is replaced atomically only
after the dump succeeds, then included in the same restic snapshot as HA state.
A dump failure aborts the backup instead of reporting success with yesterday's
dump. The dump inherits the daily backup's R2 destination and retention.

For recovery, restore `/var/backup/hass/recorder.dump` from the chosen restic
snapshot into a staging directory. With separately authorized downtime, stop HA
and use the matching PostgreSQL `pg_restore` to load it into an empty `hass`
database owned by the configured HA database user, then restart HA. Do not restore
over a running recorder or overwrite an existing database without a recovery plan.

This backs up retained history and statistics; it does not extend HA's recorder
retention or recover history already purged before the snapshot.

### Native backup integration is intentionally disabled

HA's built-in backup integration (`backup` domain) is disabled at the config-entry level (`disabled_by: "user"` in `.storage/core.config_entries`). On a native NixOS install (not HAOS), the integration has no backup agent (no Supervisor, no configured network share), so every automatic backup attempt fails with `backup_manager_error` and generates a persistent "Automatic backup could not be created" warning.

The backup integration auto-creates its config entry on every HA startup via `discovery_flow.async_create_flow` in `backup/__init__.py`, so deleting the entry is not durable — it returns on restart. Disabling it (not deleting) persists across restarts.

Restic covers `/var/lib/hass` nightly (see schedule above). The native backup integration adds no value here and is intentionally left disabled.

## Declarative Device Management

`devices.yaml` maps devices to areas and room icons. `apply-devices.py` applies both via the HA WebSocket API:

```bash
# Run manually
ssh nuc "sudo python3 /var/lib/hass/apply-devices.py /var/lib/hass/devices.yaml"
```

The script is idempotent — it creates missing areas and only updates devices whose area differs. It also runs automatically as a systemd oneshot after HA starts (`hass-apply-devices.service`).

### Shared electrical supply: Dishwasher and Trashcan

Edmund confirmed on 2026-11-05 that these Nanoleaf Essentials bulbs share one
physical power switch:

| Bulb       | Light entity               | Matter node |
| ---------- | -------------------------- | ----------- |
| Dishwasher | `light.kitchen_dishwasher` | 30          |
| Trashcan   | `light.kitchen_trashcan`   | 29          |

Switching this supply power-cycles both bulbs. Dishwasher-only electrical
recovery is not possible with this switch. Approval to recover Dishwasher alone
does not authorize a shared-switch cycle; that requires approval covering both
bulbs. A Matter light off/on command does not interrupt the electrical supply.

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
