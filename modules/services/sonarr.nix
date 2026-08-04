{
  config,
  lib,
  ...
}:
with lib;
with lib.my;
let
  cfg = config.modules.services.sonarr;
in
{
  options.modules.services.sonarr = {
    enable = mkBoolOpt false;
  }
  // lib.my.mkRegistry {
    gatus = {
      name = "Sonarr";
      order = 50;
      group = "Media";
      url = "http://localhost:8989/ping";
      conditions = [ "[STATUS] == 200" ];
      alerts = true;
    };
    homepage = {
      group = "Downloads";
      name = "Sonarr";
      order = 20;
      href = "http://nuc.cinnamon-rooster.ts.net:8989";
      description = "TV shows";
      icon = "sonarr.svg";
    };
  };

  config = mkIf cfg.enable {
    services.sonarr.enable = true;
    services.sonarr.openFirewall = true;
  };
}
