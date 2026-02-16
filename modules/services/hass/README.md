# Home Assistant Module

NixOS module running Home Assistant as an OCI container with optional Homebridge, Tailscale Service proxies, PostgreSQL recorder, and code-server sidecar.

## Enable

```nix
modules.services.hass = {
  enable = true;
  # configDir = "/home/user/HomeAssistant";  # default
};
```

## Options

| Option                         | Default                                        | Description                                |
| ------------------------------ | ---------------------------------------------- | ------------------------------------------ |
| `enable`                       | `false`                                        | Enable Home Assistant container            |
| `configDir`                    | `~/HomeAssistant`                              | Config directory mounted to `/config`      |
| `image`                        | `ghcr.io/home-assistant/home-assistant:stable` | Container image                            |
| `port`                         | `8123`                                         | Web UI port                                |
| `usbDevice`                    | `null`                                         | USB device passthrough (e.g. Zigbee stick) |
| `timezone`                     | system timezone                                | TZ environment variable                    |
| `latitude/longitude/elevation` | `null`                                         | Location env vars (`HASS_LATITUDE`, etc.)  |

### PostgreSQL Recorder

Replaces default SQLite with PostgreSQL. Mirrors the home-ops k8s setup which uses `postgres-init` initContainer + `INIT_POSTGRES_*` env vars.

```nix
modules.services.hass.postgres = {
  enable = true;
  host = "localhost";
  database = "home_assistant";
};
```

You still need to configure `configuration.yaml` recorder:

```yaml
recorder:
  db_url: postgresql://home_assistant@localhost/home_assistant
```

### Code-Server Sidecar

Edit HA config from browser. Mirrors the home-ops `patches/addons.yaml` code-server addon.

```nix
modules.services.hass.codeServer = {
  enable = true;
  port = 8443;
};
```

### Homebridge

```nix
modules.services.hass.homebridge = {
  enable = true;
  openFirewall = true;
};
```

### Tailscale Service Proxies

Expose HA and/or Homebridge via Tailscale HTTPS:

```nix
modules.services.hass.tailscaleService.enable = true;
modules.services.hass.homebridge.tailscaleService.enable = true;
```

## Home-Ops Parity

This module pulls patterns from [home-ops k8s deployment](https://github.com/edmundmiller/home-ops/tree/main/kubernetes/apps/default/home-assistant/app):

| K8s Feature                                 | Nix Equivalent                                     |
| ------------------------------------------- | -------------------------------------------------- |
| `helmrelease.yaml` (app-template)           | OCI container config                               |
| `externalsecret.yaml` (HASS_LATITUDE, etc.) | `latitude/longitude/elevation` options             |
| `postgres-init` initContainer               | `postgres.enable` → `services.postgresql`          |
| `patches/addons.yaml` code-server           | `codeServer.enable`                                |
| `volsync.yaml` restic backup                | Not yet implemented (use restic/borgbackup module) |
| nginx ingress                               | Tailscale Service proxy                            |
| ExternalIPs LoadBalancer                    | `--network=host`                                   |

## Firewall

Port `8123` (and code-server port if enabled) opened on `tailscale0` interface only.
