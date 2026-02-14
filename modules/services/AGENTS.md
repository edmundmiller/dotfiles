# Tailscale Services Pattern

Tailscale Services route HTTPS through the WireGuard overlay — **do NOT open port 443 in firewall**.

## Adding Tailscale Service Support to a Module

### 1. Module Options

```nix
options.modules.services.myservice = {
  enable = mkBoolOpt false;
  port = mkOpt types.port 8080;

  tailscaleService = {
    enable = mkBoolOpt false;
    serviceName = mkOpt types.str "myservice";
  };
};
```

### 2. Firewall (Backend Port Only)

```nix
# Only backend port - Tailscale handles HTTPS internally
networking.firewall.interfaces.tailscale0.allowedTCPPorts = [ cfg.port ];
```

### 3. Systemd Proxy Service

```nix
systemd.services.myservice-tailscale-serve = mkIf cfg.tailscaleService.enable {
  description = "Tailscale Service proxy for MyService";
  wantedBy = [ "multi-user.target" ];
  after = [ "myservice.service" "tailscaled.service" ];

  serviceConfig = {
    Type = "oneshot";
    RemainAfterExit = true;
    ExecStart = "${pkgs.bash}/bin/bash -c 'for i in $(seq 1 15); do ${pkgs.tailscale}/bin/tailscale serve --bg --service=svc:${cfg.tailscaleService.serviceName} --https=443 http://localhost:${toString cfg.port} && exit 0; sleep 1; done; exit 1'";
    ExecStop = "${pkgs.bash}/bin/bash -c '${pkgs.tailscale}/bin/tailscale serve clear svc:${cfg.tailscaleService.serviceName} || true'";
  };
};
```

### 4. Module Header

```nix
# MyService - Description
# Tailscale: https://myservice.<tailnet>.ts.net
# Direct: http://<tailscale-ip>:8080
#
# Setup (one-time):
# 1. Tailscale admin → Services → Create service
# 2. Name: "myservice", endpoint: tcp:443, tag: tag:server
# 3. Deploy: hey nuc
# 4. Approve host in admin console
```

## Examples

- `modules/services/opencode/default.nix`
- `modules/services/hass.nix`

## Manual Setup After Deploy

1. **Define service**: https://login.tailscale.com/admin/services
   - Name matches `serviceName` option
   - Endpoint: `tcp:443`
   - Add tag (e.g., `tag:server`)

2. **Deploy**: `hey nuc`

3. **Approve**: Admin console → Services → Approve pending host

4. **Access**: `https://<servicename>.<tailnet>.ts.net`
