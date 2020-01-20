# modules/dev/R.nix --- https://www.r-project.org/
#
# Bioinformatics/computational biology uses a lot of R. We're slowly moving away
# from it. But R isn't too bad. If you manage it with nix it's quite nice.
{ pkgs, ... }:
with pkgs;
let
  R-with-my-packages = rWrapper.override {
    packages = with rPackages; [ languageR lintr styler ];
  };
in { my.packages = with pkgs; [ R-with-my-packages ]; }
