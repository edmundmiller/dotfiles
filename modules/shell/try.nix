{
  config,
  lib,
  inputs,
  pkgs,
  ...
}:
with lib;
with lib.my;
let
  cfg = config.modules.shell.try;
  tryPkg = inputs.try.packages.${pkgs.stdenv.hostPlatform.system}.default;
in
{
  options.modules.shell.try = with types; {
    enable = mkBoolOpt false;
    path = mkOpt str "~/src/tries";
  };

  config = mkIf cfg.enable {
    # Add try package
    user.packages = [ tryPkg ];

    # Add shell integration via your custom zsh module
    modules.shell.zsh.rcInit = ''
      eval "$(${tryPkg}/bin/try init ${cfg.path})"
    '';
  };
}
