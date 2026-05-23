# Adding a New Service (Checklist)

End-to-end flow for adding a self-hosted service to the NUC.

## 1. Module (`modules/services/<name>.nix` or `<name>/default.nix`)

Use a single file for small services, or a directory with `default.nix` + `AGENTS.md`/README for services with operational details. Both are auto-discovered.

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

For user-facing bridge/agent services like `kittylitter`, always verify the target host after deploying. A local build or macOS rebuild does not update the NUC service; run `hey nuc` before debugging mobile/client connectivity to NUC.

```bash
ssh nuc 'systemctl --user status kittylitter --no-pager'
ssh nuc 'kittylitter probe --timeout-secs 15'
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
# 1. Create/update svc:myservice in ~/src/personal/tailnet via Tailscale API
# 2. Add svc:myservice to tailscale/policy.hujson explicit service grant
# 3. Apply tailnet ACL with OpenTofu
# 4. Deploy: hey nuc
```

## Examples

- `modules/services/agentsview/default.nix`
- `modules/services/opencode/default.nix`
- `modules/services/hass/default.nix`

## Tailscale Service Setup Source of Truth

Do **not** rely on manual admin-console approval. Tailscale service definitions and ACL grants live in `~/src/personal/tailnet`.

1. Add `svc:<name>` to `~/src/personal/tailnet/tailscale/policy.hujson` explicit service grant list.
2. Create/update the VIP service with the Tailscale API from that repo's direnv shell:

   ```bash
   cd ~/src/personal/tailnet/tailscale
   direnv exec . bash -lc '
     KEY="$TF_VAR_tailscale_api_key"
     curl -fsS -X PUT -u "$KEY:" \
       -H "Content-Type: application/json" \
       -d "{\"name\":\"svc:myservice\",\"comment\":\"My Service\",\"ports\":[\"tcp:443\"],\"tags\":[\"tag:server\"]}" \
       "https://api.tailscale.com/api/v2/tailnet/-/vip-services/svc:myservice"
   '
   ```

   If updating an existing service, include its existing two `addrs` values in the PUT body; otherwise the API returns `400`.

3. Apply ACL:

   ```bash
   cd ~/src/personal/tailnet/tailscale
   direnv exec . tofu apply -auto-approve
   ```

4. Verify:

   ```bash
   curl -fsS -u "$TF_VAR_tailscale_api_key:" \
     https://api.tailscale.com/api/v2/tailnet/-/vip-services/svc:myservice/devices | jq .
   ```

   Expected: `approvalLevel` is `approved:auto` and `configured` is `ready`.

5. Deploy service wiring:

   ```bash
   git push && hey nuc
   ```

6. Access: `https://<servicename>.<tailnet>.ts.net`
