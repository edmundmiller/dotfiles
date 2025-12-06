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
  cfg = config.modules.services.taskchampion-sync;
in
{
  options.modules.services.taskchampion-sync = {
    enable = mkBoolOpt false;
  };

  # NixOS-only service (OCI containers)
  config = mkIf cfg.enable (optionalAttrs (!isDarwin) {
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
