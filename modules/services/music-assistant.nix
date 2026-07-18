{
  config,
  lib,
  isDarwin,
  ...
}:
with lib;
with lib.my;
let
  cfg = config.modules.services.music-assistant;
in
{
  options.modules.services.music-assistant.enable = mkBoolOpt false;

  config = mkIf cfg.enable (
    optionalAttrs (!isDarwin) {
      systemd.tmpfiles.rules = [
        "d /var/lib/music-assistant 0750 root root -"
      ];

      virtualisation.oci-containers.containers.music-assistant = {
        autoStart = true;
        image = "ghcr.io/music-assistant/server:2.9.9";
        volumes = [ "/var/lib/music-assistant:/data" ];
        extraOptions = [ "--network=host" ];
      };

    }
  );
}
