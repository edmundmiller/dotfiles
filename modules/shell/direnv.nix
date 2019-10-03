{ config, lib, pkgs, ... }:

{
  nixpkgs.overlays = [
    (self: super: {
      lorri = let
        src = (super.fetchFromGitHub {
          owner = "target";
          repo = "lorri";
          rev = "38eae3d487526ece9d1b8c9bb0d27fb45cf60816";
          sha256 = "11k9lxg9cv6dlxj4haydvw4dhcfyszwvx7jx9p24jadqsy9jmbj4";
        });
      in import src { inherit src; };
    })
  ];

  environment.systemPackages = with pkgs; [ direnv lorri ];

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
