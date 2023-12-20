{
  options,
  config,
  lib,
  ...
}:
with lib;
with lib.my; let
  cfg = config.modules.services.audiobookshelf;
in {
  options.modules.services.audiobookshelf = {enable = mkBoolOpt false;};

  config = mkIf cfg.enable {
    services.audiobookshelf.enable = true;
    services.audiobookshelf.openFirewall = true;
    services.audiobookshelf.host = "0.0.0.0";

    user.extraGroups = ["audiobookshelf"];
  };
}
