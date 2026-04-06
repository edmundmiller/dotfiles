{
  config,
  lib,
  pkgs,
  isDarwin,
  ...
}:
with lib;
with lib.my;
let
  cfg = config.modules.editors.zed;
in
{
  options.modules.editors.zed = {
    enable = mkBoolOpt false;
  };

  config = mkIf cfg.enable (mkMerge [
    {
      home-manager.users.${config.user.name}.programs.zed-editor = {
        enable = true;
        package = pkgs.zed-editor;
        installRemoteServer = true;
      };
    }

    (mkIf isDarwin {
      modules.editors.file-associations = {
        enable = mkDefault true;
        editor = mkDefault "zed";
      };
    })
  ]);
}
