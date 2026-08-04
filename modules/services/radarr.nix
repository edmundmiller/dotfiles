{
  config,
  lib,
  ...
}:
with lib;
with lib.my;
let
  cfg = config.modules.services.radarr;
in
{
  options.modules.services.radarr = {
    enable = mkBoolOpt false;
  }
  // lib.my.mkRegistry {
    gatus = {
      name = "Radarr";
      order = 60;
      group = "Media";
      url = "http://localhost:7878/ping";
      conditions = [ "[STATUS] == 200" ];
      alerts = true;
    };
    homepage = {
      group = "Downloads";
      name = "Radarr";
      order = 10;
      href = "http://nuc.cinnamon-rooster.ts.net:7878";
      description = "Movies";
      icon = "radarr.svg";
    };
  };

  config = mkIf cfg.enable {
    services.radarr.enable = true;
    services.radarr.openFirewall = true;
  };
}
