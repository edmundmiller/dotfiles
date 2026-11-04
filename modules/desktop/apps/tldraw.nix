{
  config,
  lib,
  pkgs,
  isDarwin,
  ...
}:
let
  cfg = config.modules.desktop.apps.tldraw;
  tldrawApi = pkgs.writeShellScriptBin "tldraw-api" ''
    exec ${pkgs.python3}/bin/python3 ${../../../config/tldraw/tldraw-api.py} "$@"
  '';
in
{
  options.modules.desktop.apps.tldraw.enable = lib.my.mkBoolOpt false;

  config = lib.mkMerge [
    (lib.mkIf cfg.enable {
      assertions = [
        {
          assertion = isDarwin;
          message = "modules.desktop.apps.tldraw currently supports macOS only.";
        }
      ];
      home-manager.users.${config.user.name}.home.packages = [ tldrawApi ];
    })
    (lib.optionalAttrs isDarwin {
      homebrew.casks = lib.mkIf cfg.enable [ "tldraw" ];
    })
  ];
}
