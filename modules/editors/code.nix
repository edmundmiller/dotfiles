{
  config,
  options,
  lib,
  pkgs,
  ...
}:
with lib;
with lib.my; let
  cfg = config.modules.editors.code;
in {
  options.modules.editors.code = {enable = mkBoolOpt false;};

  config = mkIf cfg.enable {
    home-manager.users.emiller.programs.vscode = {
      enable = true;
      extensions = with pkgs.vscode-extensions; [
        ms-toolsai.jupyter
        # nf-core.nf-core-extensionpack
        github.copilot
        github.copilot-chat
        # gitpod.gitpod-desktop
        eamodio.gitlens
        bbenoist.nix
        # reditorsupport.r
      ];
    };
    # For Liveshare
    services.gnome.gnome-keyring.enable = true;
    programs.seahorse.enable = true;
    # FIXME if kde
    programs.ssh.askPassword = lib.mkForce "${pkgs.libsForQt5.ksshaskpass}/libexec/ksshaskpass";
    programs.dconf.enable = true;
  };
}
