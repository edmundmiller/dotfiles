# Gatus Uptime Monitoring

Automated service health monitoring for NUC using [Gatus](https://gatus.io/).

## Installation

Enable in host config:

```nix
modules.services = {
  gatus = {
    enable = true;
    tailscaleService.enable = true;
  };
};
```

Deploy:

```bash
hey nuc
```

## Access

- **Tailscale:** `https://gatus.cinnamon-rooster.ts.net`
- **Direct:** `http://<nuc-ip>:8084`

## One-Time Tailscale Setup

1. Go to [Tailscale admin → Services](https://login.tailscale.com/admin/services)
2. Create service: name `gatus`, endpoint `tcp:443`, tag `tag:server`
3. Deploy with `hey nuc`
4. Approve pending host in admin console

## Configuration Options

| Option                         | Default   | Description                |
| ------------------------------ | --------- | -------------------------- |
| `enable`                       | `false`   | Enable Gatus service       |
| `port`                         | `8084`    | Web UI / API port          |
| `tailscaleService.enable`      | `false`   | Expose via Tailscale serve |
| `tailscaleService.serviceName` | `"gatus"` | Tailscale service name     |

## Monitored Services

### Smart Home

- **Home Assistant** — `http://localhost:8123/api/`
- **Homebridge** — `http://localhost:8581`
- **Matter Server** — `tcp://localhost:5580`

### Media

- **Jellyfin** — `http://localhost:8096/health`
- **Sonarr** — `http://localhost:8989/ping`
- **Radarr** — `http://localhost:7878/ping`
- **Prowlarr** — `http://localhost:9696/ping`
- **Audiobookshelf** — `http://localhost:13378/healthcheck` (conditional)

### Infrastructure

- **PostgreSQL** — `tcp://localhost:5432`
- **Tailscale** — `http://localhost:41112/healthz`

## Adding Endpoints

Edit `default.nix` and add to the `endpoints` list:

```nix
{
  name = "My Service";
  group = "Category";
  url = "http://localhost:PORT/health";
  interval = "60s";
  conditions = [ "[STATUS] == 200" ];
}
```

For services that may not always be enabled:

```nix
++ optionals config.modules.services.myservice.enable [ { ... } ]
```

## Troubleshooting

**Service not starting:**

```bash
hey nuc-service gatus
hey nuc-logs gatus 50
```

**Dashboard unreachable via Tailscale:**

```bash
hey nuc-service gatus-tailscale-serve
ssh nuc "tailscale serve status"
```

**Endpoint showing down but service is running:**

Check the endpoint URL is correct and accessible from localhost on the NUC. Some services need time to start — Gatus retries automatically.

**Storage/data issues:**

```bash
ssh nuc "ls -la /var/lib/gatus/"
```

SQLite DB is managed by `DynamicUser` with `StateDirectory = "gatus"`.
