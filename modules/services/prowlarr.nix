{
  config,
  lib,
  ...
}:
with lib;
with lib.my;
let
  cfg = config.modules.services.prowlarr;
in
{
  options.modules.services.prowlarr = {
    enable = mkBoolOpt false;
  }
  // lib.my.mkRegistry {
    gatus = {
      name = "Prowlarr";
      order = 70;
      group = "Media";
      url = "http://localhost:9696/ping";
      conditions = [ "[STATUS] == 200" ];
      alerts = true;
    };
    homepage = {
      group = "Downloads";
      name = "Prowlarr";
      order = 30;
      href = "http://nuc.cinnamon-rooster.ts.net:9696";
      description = "Indexer manager";
      icon = "prowlarr.svg";
    };
  };

  config = mkIf cfg.enable {
    services.prowlarr.enable = true;
    services.prowlarr.openFirewall = true;
  };
}
