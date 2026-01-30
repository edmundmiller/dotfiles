# modules/dev/julia.nix --- Julia
{
  config,
  lib,
  pkgs,
  ...
}:
with lib;
with lib.my;
let
  cfg = config.modules.dev.julia;
in
{
  options.modules.dev.julia = {
    enable = mkBoolOpt false;
  };

  config = mkIf cfg.enable {
    user.packages = with pkgs; [
      julia-bin
      # Plots.jl
      mesa
      libsForQt5.qt5.qtbase
    ];

    # TODO
    # home.configFile = {
    # };
  };
}
