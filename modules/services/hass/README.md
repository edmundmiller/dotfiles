# Home Assistant Module

Native NixOS `services.home-assistant` module with declarative config, PostgreSQL recorder, Homebridge, and Tailscale Service proxies.

## Enable

```nix
modules.services.hass = {
  enable = true;
  postgres.enable = true; # recommended: faster than SQLite
};
```

## What You Get

- Native `services.home-assistant` (not OCI container) — 98% integration support
- Declarative `configuration.yaml` via nix with `default_config`
- UI automations/scenes/scripts (`!include` + tmpfiles for empty yaml)
- HTTP bound to `::1` with `use_x_forwarded_for` (ready for reverse proxy)
- Firewall opens HA port on `tailscale0` only

## Options

| Option                  | Default  | Description                                                   |
| ----------------------- | -------- | ------------------------------------------------------------- |
| `enable`                | `false`  | Enable Home Assistant                                         |
| `usbDevice`             | `null`   | USB device passthrough (Zigbee/Z-Wave stick)                  |
| `extraComponents`       | `[]`     | Additional integrations (merged with onboarding defaults)     |
| `customComponents`      | `[]`     | Packages from `pkgs.home-assistant-custom-components.*`       |
| `customLovelaceModules` | `[]`     | Packages from `pkgs.home-assistant-custom-lovelace-modules.*` |
| `postgres.enable`       | `false`  | Use PostgreSQL recorder (provisions db + user)                |
| `postgres.database`     | `"hass"` | Database name                                                 |
| `postgres.user`         | `"hass"` | Database user                                                 |

### Homebridge

```nix
modules.services.hass.homebridge.enable = true;
```

### Tailscale Service Proxies

```nix
modules.services.hass.tailscaleService.enable = true;
modules.services.hass.homebridge.tailscaleService.enable = true;
```

## Migration from OCI Container

Previous module ran `ghcr.io/home-assistant/home-assistant:stable` via `virtualisation.oci-containers`. Native module uses `services.home-assistant` which:

- Auto-resolves component dependencies from `config` attrset
- Supports `customComponents` and `customLovelaceModules` from nixpkgs
- Manages config dir at `/var/lib/hass` (NixOS default)
- Runs as `hass` user (not root/privileged container)

### Data Migration

Run `migrate-hass.sh` on the NUC (as root):

```bash
sudo bash /etc/hass/migrate-hass.sh
```

The script:

1. Stops old container + new native service
2. Copies config from `~/HomeAssistant` → `/var/lib/hass`
3. Removes stale files managed by nix (`configuration.yaml`, etc.)
4. Fixes ownership to `hass:hass`
5. Starts native HA service

If migrating to postgres, HA handles recorder migration on startup — just enable `postgres.enable` and rebuild.

**Manual fallback:**

```bash
systemctl stop podman-homeassistant 2>/dev/null || true
systemctl stop home-assistant
cp -a ~/HomeAssistant/* /var/lib/hass/
rm -f /var/lib/hass/configuration.yaml  # nix manages this
chown -R hass:hass /var/lib/hass
systemctl start home-assistant
```

## Home-Ops Parity

Patterns from [home-ops k8s deployment](https://github.com/edmundmiller/home-ops/tree/main/kubernetes/apps/default/home-assistant/app):

| K8s Feature                      | Nix Equivalent                                         |
| -------------------------------- | ------------------------------------------------------ |
| `helmrelease.yaml` app-template  | Native `services.home-assistant`                       |
| `externalsecret.yaml` (location) | Set in HA UI or `config.homeassistant`                 |
| `postgres-init` initContainer    | `postgres.enable` → `services.postgresql` + `psycopg2` |
| `volsync.yaml` restic backup     | Use restic/borgbackup module on `/var/lib/hass`        |
| nginx ingress                    | Tailscale Service proxy (or add nginx vhost)           |
| code-server addon                | Not needed — edit nix config directly                  |
