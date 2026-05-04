{
  config,
  lib,
  isDarwin,
  ...
}:
with lib;
with lib.my;
let
  cfg = config.modules.services.timew_sync;
  dataDir = "/home/emiller/timew-sync-server";
in
{
  options.modules.services.timew_sync = {
    enable = mkBoolOpt false;
    port = mkOpt types.port 8081;
  };

  # NixOS-only service (OCI container).
  config = mkIf cfg.enable (
    optionalAttrs (!isDarwin) {
      virtualisation.podman = {
        enable = true;
        # Required for containers to communicate via DNS.
        defaultNetwork.settings.dns_enabled = true;
      };

      virtualisation.oci-containers.backend = "podman";

      systemd.tmpfiles.rules = [
        "d ${dataDir} 0750 emiller users -"
        "d ${dataDir}/authorized_keys 0750 emiller users -"
      ];

      virtualisation.oci-containers.containers."timew-sync-server" = {
        autoStart = true;
        image = "timewarrior-synchronize/timew-sync-server:latest";
        ports = [ "${toString cfg.port}:8080" ];
        volumes = [ "${dataDir}:/app/data:rw" ];
        cmd = [
          "start"
          "--port"
          "8080"
          "--no-auth"
          "--keys-location"
          "/app/data/authorized_keys"
          "--sqlite-db"
          "/app/data/db.sqlite"
        ];
      };

      networking.firewall.allowedTCPPorts = [ cfg.port ];
    }
  );
}
