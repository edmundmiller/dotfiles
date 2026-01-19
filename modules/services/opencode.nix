# OpenCode - AI coding agent web interface
# Access via Tailscale at http://<tailscale-ip>:4096
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
  });
}
