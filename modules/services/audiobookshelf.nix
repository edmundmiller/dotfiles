# Audiobookshelf - self-hosted audiobooks and podcasts
# Dashboard: http://<nuc-tailscale-ip>:13378
{
  config,
  lib,
  isDarwin,
  ...
}:
with lib;
with lib.my;
let
  cfg = config.modules.services.audiobookshelf;
in
{
  options.modules.services.audiobookshelf = {
    enable = mkBoolOpt false;
    port = mkOpt types.port 13378;
  };

  # NixOS-only service
  config = mkIf cfg.enable (
    optionalAttrs (!isDarwin) {
      services.audiobookshelf = {
        enable = true;
        openFirewall = true;
        host = "0.0.0.0";
        inherit (cfg) port;
      };

      user.extraGroups = [ "audiobookshelf" ];
    }
  );
}
