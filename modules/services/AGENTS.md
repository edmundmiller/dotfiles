# Adding a New Service (Checklist)

End-to-end flow for adding a self-hosted service to the NUC.

## 1. Module (`modules/services/<name>.nix`)

Wrap the upstream NixOS module. Follow the audiobookshelf/lubelogger pattern:

```nix
{ config, lib, isDarwin, ... }:
with lib; with lib.my;
let cfg = config.modules.services.<name>;
in {
  options.modules.services.<name> = {
    enable = mkBoolOpt false;
    environmentFile = mkOption {
      type = types.nullOr types.path;
      default = null;
      description = "Path to env file for secrets.";
    };
  };
  config = mkIf cfg.enable (optionalAttrs (!isDarwin) {
    services.<name> = {
      enable = true;
      environmentFile = cfg.environmentFile;
    };
  });
}
```

## 2. Host Config (`hosts/nuc/default.nix`)

```nix
modules.services.<name>.enable = true;
```

## 3. Secrets (if service needs credentials)

See the `agenix-secrets` skill. Quick summary:

1. Generate creds → store in 1Password (`op item create`)
2. Create `hosts/nuc/secrets/<name>-env.age` (encrypted env file)
3. Add entry to `hosts/nuc/secrets/secrets.nix`
4. Wire in host config: `environmentFile = config.age.secrets.<name>-env.path;`
5. Override owner: `age.secrets.<name>-env.owner = "<service-user>";`

## 4. Gatus (`modules/services/gatus/default.nix`)

Add conditional health check endpoint:

```nix
++ optionals config.modules.services.<name>.enable [
  {
    name = "<Name>";
    group = "<Group>";
    url = "http://localhost:<port>";
    interval = "60s";
    conditions = [ "[STATUS] < 500" ];
  }
]
```

## 5. Homepage (`modules/services/homepage.nix`)

Add card to appropriate group. Include widget if supported (check gethomepage.dev/widgets/services/):

```nix
{
  "<Name>" = {
    href = "${nucBase}:<port>";
    description = "...";
    icon = "<name>.svg";
    widget = {
      type = "<name>";
      url = "http://localhost:<port>";
      username = "{{HOMEPAGE_VAR_<NAME>_USERNAME}}";
      password = "{{HOMEPAGE_VAR_<NAME>_PASSWORD}}";
    };
  };
}
```

Add `HOMEPAGE_VAR_*` entries to `homepage-env.age` (decrypt → append → re-encrypt).

## 6. Deploy

```bash
git push && hey nuc
```

---

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
