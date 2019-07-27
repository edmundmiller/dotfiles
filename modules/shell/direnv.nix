{ config, lib, pkgs, ... }:

{
  environment.systemPackages = with pkgs; [ direnv ];

  programs = {
    bash.interactiveShellInit = ''
      eval "$(${pkgs.direnv}/bin/direnv hook bash)"
    '';
    zsh.interactiveShellInit = ''
      eval "$(${pkgs.direnv}/bin/direnv hook zsh)"
    '';
    fish.interactiveShellInit = ''
      eval (${pkgs.direnv}/bin/direnv hook fish)
    '';
  };

  home-manager.users.emiller = {
    xdg.configFile = {
      "zsh/rc.d/aliases.direnv.zsh".source = <config/direnv/aliases.zsh>;
      "direnv/direnvrc".source = <config/direnv/direnvrc>;
    };
  };
}
