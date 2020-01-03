{ config, lib, pkgs, ... }:
with pkgs;
let
  R-with-my-packages = rWrapper.override {
    packages = with rPackages; [ languageR lintr styler ];
  };
in {
  environment.systemPackages = with pkgs; [ R-with-my-packages ];

  home-manager.users.emiller.xdg.configFile = {
    # "zsh/rc.d/aliases.R.zsh".source = <config/R/aliases.zsh>;
    # "zsh/rc.d/env.R.zsh".source = <config/R/env.zsh>;
  };
}
