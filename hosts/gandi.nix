{
  lib,
  pkgs,
  ...
}:
with lib; {
  imports = [./gandicloud.nix];

  modules = {
    editors = {
      default = "nvim";
      vim.enable = true;
    };
    shell = {
      git.enable = true;
      zsh.enable = true;
    };
    services.ssh.enable = true;
  };

  environment.systemPackages = with pkgs; [inetutils mtr sysstat git];
}
