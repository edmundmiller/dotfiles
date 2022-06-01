{ config, options, lib, pkgs, inputs, ... }:

with lib;
with lib.my;
let cfg = config.modules.editors.code;
in {
  options.modules.editors.code = { enable = mkBoolOpt false; };

  config = mkIf cfg.enable {

    home-manager.users.emiller.programs.vscode.enable = true;
    home-manager.users.emiller.programs.vscode.package =
      pkgs.unstable.vscode-fhsWithPackages
      (ps: with ps; [ editorconfig-core-c hub neovim ]);

    # For Liveshare
    services.gnome.gnome-keyring.enable = true;
    programs.seahorse.enable = true;
  };
}
