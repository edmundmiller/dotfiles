{ lib, pkgs, ... }:
with lib;
{
  imports = [
    ./gandicloud.nix
    ../_server.nix
  ];

  modules = {
    editors = {
      default = "nvim";
      vim.enable = true;
    };
    shell = {
      git.enable = true;
      zsh.enable = true;
    };
    services = {
      ssh.enable = true;
      syncthing.enable = true;
      tailscale.enable = true;
    };
  };

  environment.systemPackages = with pkgs; [
    inetutils
    mtr
    sysstat
    git
  ];
}
