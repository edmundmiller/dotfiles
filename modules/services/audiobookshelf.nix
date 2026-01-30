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
  };

  # NixOS-only service
  config = mkIf cfg.enable (
    optionalAttrs (!isDarwin) {
      services.audiobookshelf.enable = true;
      services.audiobookshelf.openFirewall = true;
      services.audiobookshelf.host = "0.0.0.0";

      user.extraGroups = [ "audiobookshelf" ];
    }
  );
}
