{
  config,
  lib,
  isDarwin,
  ...
}:
with lib;
with lib.my;
let
  cfg = config.modules.desktop.term;
in
{
  options.modules.desktop.term = {
    default = mkOpt types.str "xterm";
  };

  config = mkMerge [
    {
      env.TERMINAL = cfg.default;
    }

    # NixOS-only X11 desktop manager configuration
    (optionalAttrs (!isDarwin) {
      services.xserver.desktopManager.xterm.enable = mkDefault (cfg.default == "xterm");
    })
  ];
}
