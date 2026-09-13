{
  config,
  lib,
  isDarwin,
  ...
}:
with lib;
with lib.my;
let
  cfg = config.modules.desktop.apps.notion;
in
{
  options.modules.desktop.apps.notion.enable = mkBoolOpt false;

  config = optionalAttrs isDarwin (
    mkIf cfg.enable {
      homebrew.casks = [ "notion" ];
    }
  );
}
