# OpenCode - AI coding agent web interface
# Access via Tailscale Service: http://opencode.<tailnet>.ts.net:4096
# Or direct: http://<tailscale-ip>:4096
#
# Tailscale Service setup (one-time manual steps):
# 1. Go to Tailscale admin console → Services → Create service
# 2. Name: "opencode", endpoint: tcp:4096, add tag (e.g., tag:server)
# 3. After deploy, approve NUC as service host in admin console
# 4. Access at http://opencode.<tailnet>.ts.net:4096
{
  options,
  config,
  lib,
  pkgs,
  isDarwin,
  ...
}:
with lib;
with lib.my;
let
  cfg = config.modules.services.opencode;
in
{
  options.modules.services.opencode = {
    enable = mkBoolOpt false;
    projectDir = mkOpt types.str "${config.user.home}/src";
    image = mkOpt types.str "ghcr.io/anomalyco/opencode:latest";
    port = mkOpt types.port 4096;
    password = mkOpt types.str ""; # Optional: OPENCODE_SERVER_PASSWORD

    # Tailscale Service integration
    tailscaleService = {
      enable = mkBoolOpt true;
      serviceName = mkOpt types.str "opencode";
    };
  };

  # NixOS-only service (uses OCI containers with existing backend)
  config = optionalAttrs (!isDarwin) (mkIf cfg.enable {
    # Create project directory if it doesn't exist
    systemd.tmpfiles.rules = [
      "d ${cfg.projectDir} 0755 ${config.user.name} users -"
    ];

    # OpenCode web container
    virtualisation.oci-containers.containers.opencode = {
      autoStart = true;
      image = cfg.image;
      # Backup: set `user = "<uid>:<gid>"` (see `id -u/-g`) if you want host-owned files.
      volumes = [ "${cfg.projectDir}:/app" ];
      extraOptions = [
        "--network=host"
        "--health-cmd=/bin/sh -c 'wget -q --spider http://127.0.0.1:${toString cfg.port} || exit 1'"
        "--health-interval=30s"
        "--health-timeout=10s"
        "--health-start-period=30s"
        "--health-retries=3"
      ];

      # Bind on all interfaces; firewall restricts to Tailscale
      entrypoint = "/bin/sh";
      cmd = [
        "-c"
        ''
          ${optionalString (cfg.password != "") "export OPENCODE_SERVER_PASSWORD='${cfg.password}'"}
          exec opencode web --hostname 0.0.0.0 --port ${toString cfg.port}
        ''
      ];
    };

    # Add restart delay to the generated systemd service
    # Service name depends on backend: podman-opencode or docker-opencode
    # Note: OCI containers module already sets Restart = "always"
    systemd.services."${config.virtualisation.oci-containers.backend}-opencode" = {
      serviceConfig = {
        RestartSec = mkForce "10s";
      };
    };

    # Open firewall port on Tailscale only
    networking.firewall.interfaces.tailscale0.allowedTCPPorts = [ cfg.port ];

    # Tailscale Service proxy (TCP forwarder to local OpenCode)
    systemd.services.opencode-tailscale-serve = mkIf cfg.tailscaleService.enable {
      description = "Tailscale Service proxy for OpenCode";
      wantedBy = [ "multi-user.target" ];
      after = [
        "${config.virtualisation.oci-containers.backend}-opencode.service"
        "tailscaled.service"
      ];

      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = "${pkgs.tailscale}/bin/tailscale serve --bg --service=svc:${cfg.tailscaleService.serviceName} --tcp=${toString cfg.port} tcp://localhost:${toString cfg.port}";
        ExecStop = "${pkgs.tailscale}/bin/tailscale serve reset";
      };
    };
  });
}
