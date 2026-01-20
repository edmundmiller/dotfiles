# OpenCode Service

AI coding agent web interface accessible via Tailscale.

## Access

- **URL:** https://opencode.cinnamon-rooster.ts.net
- **Direct:** http://100.112.179.64:4096

## Enable

In your host config (e.g., `hosts/nuc/default.nix`):

```nix
modules.services.opencode.enable = true;
```

## Options

| Option                          | Default                             | Description                  |
| ------------------------------- | ----------------------------------- | ---------------------------- |
| `enable`                        | `false`                             | Enable OpenCode service      |
| `projectDir`                    | `~/src`                             | Directory mounted in container |
| `image`                         | `ghcr.io/anomalyco/opencode:latest` | Container image              |
| `port`                          | `4096`                              | Backend port                 |
| `password`                      | `""`                                | Optional server password     |
| `tailscaleService.enable`       | `true`                              | Enable Tailscale Service     |
| `tailscaleService.serviceName`  | `"opencode"`                        | Tailscale service name       |

## Tailscale Service Setup

### Prerequisites

1. Host must be tagged (e.g., `tag:server`) in Tailscale admin
2. Service "opencode" must be defined in admin console with endpoint `https:443`

### First-Time Setup

1. **Tag the host:**
   ```bash
   sudo tailscale logout
   sudo tailscale up --auth-key=tskey-auth-xxxxx --advertise-tags=tag:server
   ```

2. **Create service in admin console:**
   - Go to Tailscale Admin > Services > Create
   - Name: `opencode`
   - Endpoint: `https:443`

3. **Deploy and approve:**
   ```bash
   hey nuc  # or deploy to your host
   ```
   - Approve host in Tailscale admin console

## Troubleshooting

### Container won't start

```bash
# Check container logs
ssh nuc "sudo podman logs opencode"

# Check systemd service
ssh nuc "systemctl status podman-opencode"
```

### Tailscale Service not working

```bash
# Check serve logs
ssh nuc "sudo journalctl -u opencode-tailscale-serve.service -n 50"

# Restart serve proxy
ssh nuc "sudo systemctl restart opencode-tailscale-serve"
```

### "Approval required" error

- Check Tailscale admin console > Services > opencode
- Approve the host if showing as pending

### Port mismatch error

- Ensure admin console endpoint matches module config
- Currently: `https:443` in admin, `--https=443` in module

## Architecture

```
Internet (blocked)
       X
       
Tailscale Network
       |
       v
[https://opencode.cinnamon-rooster.ts.net]
       |
       v (TLS termination)
[Tailscale serve --https=443]
       |
       v (HTTP)
[localhost:4096]
       |
       v
[podman container: opencode]
       |
       v (volume mount)
[~/src]
```
