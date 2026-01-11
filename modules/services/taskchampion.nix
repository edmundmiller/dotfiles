{
  options,
  config,
  lib,
  isDarwin,
  ...
}:
with lib;
with lib.my;
let
  cfg = config.modules.services.taskchampion;
in
{
  options.modules.services.taskchampion = {
    enable = mkBoolOpt false;
  };

  # NixOS-only service (OCI containers)
  config = optionalAttrs (!isDarwin) (mkIf cfg.enable {
      # Enable podman for OCI containers
      virtualisation.podman = {
        enable = true;
        # Required for containers to communicate via DNS
        defaultNetwork.settings.dns_enabled = true;
      };

      # Explicitly use podman backend for OCI containers
      virtualisation.oci-containers.backend = "podman";

      # Ensure data directory exists with correct permissions
      systemd.tmpfiles.rules = [
        "d /home/emiller/taskchampion-sync-server 0750 emiller users -"
      ];

      virtualisation.oci-containers.containers."taskchampion-sync-server" = {
        autoStart = true;
        image = "ghcr.io/gothenburgbitfactory/taskchampion-sync-server:latest";
        ports = [ "8080:8080" ];
        volumes = [
          "/home/emiller/taskchampion-sync-server:/var/lib/taskchampion-sync-server/data"
        ];
        environment = {
          RUST_LOG = "info";
        };
      };

      networking.firewall.allowedTCPPorts = [ 8080 ];
    });
}
