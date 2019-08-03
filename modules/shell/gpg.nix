{ config, lib, pkgs, ... }:

{
  environment.systemPackages = with pkgs; [ pinentry_emacs pinentry ];

  home-manager.users.emiller = {
    programs.gpg = {
      enable = true;
    };
    services.gpg-agent = {
      enable = true;
      defaultCacheTtl = 28800;
      maxCacheTtl = 28800;
    };
  };
}
