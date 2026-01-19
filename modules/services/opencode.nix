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
        "--health-cmd=wget -q --spider http://localhost:${toString cfg.port} || exit 1"
        "--health-interval=30s"
        "--health-timeout=10s"
        "--health-retries=3"
      ];

      # Detect Tailscale IP at runtime and bind to it
      entrypoint = "/bin/sh";
      cmd = [
        "-c"
        ''
          TS_IP=$(cat /proc/net/fib_trie 2>/dev/null | grep -oP '100\.\d+\.\d+\.\d+' | head -1)
          ${optionalString (cfg.password != "") "export OPENCODE_SERVER_PASSWORD='${cfg.password}'"}
          exec opencode web --hostname ''${TS_IP:-127.0.0.1} --port ${toString cfg.port}
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

    # Open firewall port for Tailscale traffic
    networking.firewall.allowedTCPPorts = [ cfg.port ];
  });
}
