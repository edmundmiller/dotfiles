{ config, lib, pkgs, ... }:

{
  services.lorri.enable = true;

  my = {
    packages = [ pkgs.direnv ];
    # FIXME This is slow but it works
    zsh.rc = ''eval "$(${pkgs.direnv}/bin/direnv hook zsh)"'';
    home.xdg.configFile = {
      "direnv/direnvrc".source = <config/direnv/direnvrc>;
    };
  };
}
