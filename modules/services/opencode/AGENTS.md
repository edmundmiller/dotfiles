# OpenCode Service Module

AI coding agent web interface running on NUC, accessible via Tailscale Service.

## Quick Facts

- **Access URL:** `https://opencode.cinnamon-rooster.ts.net`
- **Direct access:** `http://100.112.179.64:4096` (Tailscale IP)
- **Container:** `ghcr.io/anomalyco/opencode:latest` via podman
- **Backend port:** 4096 (localhost only)
- **Tailscale Service:** `svc:opencode` with HTTPS on 443

## Module Options

```nix
modules.services.opencode = {
  enable = true;
  projectDir = "~/src";           # Mounted as /app in container
  image = "ghcr.io/anomalyco/opencode:latest";
  port = 4096;                    # Backend port
  password = "";                  # Optional: OPENCODE_SERVER_PASSWORD
  tailscaleService.enable = true; # Tailscale Service integration
  tailscaleService.serviceName = "opencode";
};
```

## Architecture

```
[Browser]
    |
    v (HTTPS:443, TLS terminated by Tailscale)
[Tailscale Service: svc:opencode]
    |
    v (HTTP to localhost:4096)
[podman-opencode container]
    |
    v (volume mount)
[~/src project files]
```

## Systemd Services

| Service                            | Purpose                         |
| ---------------------------------- | ------------------------------- |
| `podman-opencode.service`          | Main container running OpenCode |
| `opencode-tailscale-serve.service` | Tailscale HTTPS proxy (oneshot) |

## Tailscale Service Setup (One-Time)

Already configured for NUC. If setting up on new host:

1. Tag host with `tag:server` in Tailscale admin
2. Create service "opencode" with endpoint `https:443`
3. Deploy module, approve host in admin console

## Key Files

- `modules/services/opencode/default.nix` - Module definition
- `hosts/nuc/default.nix` - Enables `opencode.enable = true`

## Gotchas

- **Container user:** Runs as root inside container (not host user)
- **Tailscale serve status:** Shows "No serve config" for service proxies - this is normal
- **Deploy timeout:** deploy-rs may timeout but config still applies; check logs
- **Service definition:** Must match between admin console and module (`https:443`)

## Troubleshooting

```bash
# Check container status
ssh nuc "systemctl status podman-opencode"

# Check Tailscale serve logs
ssh nuc "sudo journalctl -u opencode-tailscale-serve.service -n 50"

# Verify service is advertising
ssh nuc "sudo tailscale status --json | jq .Self.ServiceProxies"

# Restart serve proxy
ssh nuc "sudo systemctl restart opencode-tailscale-serve"
```

## Related Documentation

- [OpenCode Web Docs](https://opencode.ai/docs/web/)
- [Tailscale Services](https://tailscale.com/kb/1552/tailscale-services)
