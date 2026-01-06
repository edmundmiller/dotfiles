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
  cfg = config.modules.services.timew_sync;
  homeDir = config.users.users.${config.user.name}.home;
in
{
  options.modules.services.timew_sync = {
    enable = mkBoolOpt false;
  };

  # NixOS-only service (OCI containers)
  config = mkIf cfg.enable (optionalAttrs (!isDarwin) {
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
      "d ${homeDir}/timew-sync-server 0750 ${config.user.name} users -"
      "d ${homeDir}/timew-sync-server/authorized_keys 0750 ${config.user.name} users -"
    ];

    virtualisation.oci-containers.containers."timew-sync-server" = {
      autoStart = true;
      image = "timewarrior-synchronize/timew-sync-server:latest";
      ports = [ "8081:8080" ];
      volumes = [
        "${homeDir}/timew-sync-server:/app/data"
      ];
      # TODO: Remove --no-auth after testing and add proper authentication
      cmd = [ "start" "--port" "8080" "--no-auth" "--keys-location" "/app/data/authorized_keys" ];
      environment = {
        # Add any environment variables if needed
      };
    };

    networking.firewall.allowedTCPPorts = [ 8081 ];
  });
}