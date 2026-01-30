# modules/dev/R.nix --- https://www.r-project.org/
#
# Bioinformatics/computational biology uses a lot of R. We're slowly moving away
# from it. But R isn't too bad. If you manage it with nix it's quite nice.
{
  config,
  lib,
  pkgs,
  ...
}:
with lib;
with lib.my;
let
  cfg = config.modules.dev.R;
  R-with-my-packages = pkgs.rWrapper.override {
    packages = with pkgs.rPackages; [
      ggplot2
      languageR
      languageserver
      lintr
      styler
      tidyverse
    ];
  };
in
{
  options.modules.dev.R = {
    enable = mkBoolOpt false;
  };

  config = mkIf cfg.enable {
    user.packages = with pkgs; [
      R-with-my-packages
      # knitr
      pandoc
      unstable.quarto
    ];
    environment.variables.R_PROFILE = "$XDG_CONFIG_HOME/R/Rprofile";
  };
}
