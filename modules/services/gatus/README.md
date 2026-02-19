# Gatus Uptime Monitoring

Automated service health monitoring for NUC using [Gatus](https://gatus.io/). Alerts via Telegram on downtime, pings healthchecks.io as dead man's switch.

## Installation

Enable in host config:

```nix
modules.services = {
  gatus = {
    enable = true;
    tailscaleService.enable = true;
    alerting.telegram = {
      enable = true;
      botTokenFile = config.age.secrets.telegram-bot-token.path;
      chatId = "8357890648";
    };
    healthcheck = {
      enable = true;
      pingUrl = "https://hc-ping.com/<uuid>";
    };
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

| Option                           | Default   | Description                                     |
| -------------------------------- | --------- | ----------------------------------------------- |
| `enable`                         | `false`   | Enable Gatus service                            |
| `port`                           | `8084`    | Web UI / API port                               |
| `tailscaleService.enable`        | `false`   | Expose via Tailscale serve                      |
| `tailscaleService.serviceName`   | `"gatus"` | Tailscale service name                          |
| `alerting.telegram.enable`       | `false`   | Send alerts via Telegram                        |
| `alerting.telegram.botTokenFile` | `""`      | Path to file with bot token                     |
| `alerting.telegram.chatId`       | `""`      | Telegram chat ID for alerts                     |
| `healthcheck.enable`             | `false`   | Enable healthchecks.io dead man's switch        |
| `healthcheck.pingUrl`            | `""`      | Full ping URL (e.g. `https://hc-ping.com/uuid`) |
| `healthcheck.interval`           | `"2min"`  | Ping interval                                   |

## Alerting

### Telegram

Alerts on endpoint failure (3 consecutive failures) and recovery (2 consecutive successes). The bot token is managed via agenix and injected at runtime — never in the nix store.

### Dead Man's Switch (healthchecks.io)

A systemd timer pings the healthchecks.io URL every 2 minutes. If the NUC goes down or Gatus stops running, the ping stops and healthchecks.io sends an external alert.

**Setup:** Create a check at [healthchecks.io](https://healthchecks.io), set period to 2 minutes with 5 minute grace, copy the ping URL.

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
- **OpenClaw Gateway** — `http://localhost:18789` (conditional)

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

Alerts are automatically attached to all endpoints.

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

**Config issues (check runtime config):**

```bash
ssh nuc "sudo cat /run/gatus/config.yaml"
```

**Telegram alerts not working:**

```bash
# Verify secret is readable
ssh nuc "sudo cat /run/agenix/telegram-bot-token"

# Check gatus logs for telegram errors
ssh nuc "journalctl -u gatus -n 50 --no-pager" | grep -i telegram
```

**Dead man's switch not pinging:**

```bash
hey nuc-service gatus-healthcheck-ping
ssh nuc "systemctl list-timers gatus-healthcheck-ping.timer"
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
