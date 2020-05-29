{ config, options, lib, pkgs, ... }:
with lib; {
  options.modules.editors.vscode = {
    enable = mkOption {
      type = types.bool;
      default = false;
    };
  };
  imports = [
    (fetchTarball "https://github.com/msteen/nixos-vsliveshare/tarball/master")
  ];

  config = mkIf config.modules.editors.vscode.enable {

    nixpkgs.config.allowUnfree = true;
    my.home = {
      programs.vscode = {
        enable = true;
        package = pkgs.vscodium;
        userSettings = { };
      };
    };

    services.vsliveshare = {
      enable = true;
      extensionsDir = "$HOME/.vscode-oss/extensions";
      nixpkgs = fetchTarball
        "https://github.com/NixOS/nixpkgs/tarball/61cc1f0dc07c2f786e0acfd07444548486f4153b";
    };
  };
}
