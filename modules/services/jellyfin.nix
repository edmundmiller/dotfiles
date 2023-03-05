# Finally, a decent open alternative to Plex!

{ options, config, lib, pkgs, ... }:

with lib;
with lib.my;
let cfg = config.modules.services.jellyfin;
in {
  options.modules.services.jellyfin = { enable = mkBoolOpt false; };

  config = mkIf cfg.enable {
    services.jellyfin.enable = true;
    services.jellyfin.openFirewall = true;

    services.jellyfin.user = "kah";
    user.extraGroups = [ "jellyfin" ];
  };
}
