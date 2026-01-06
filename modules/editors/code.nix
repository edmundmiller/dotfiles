{
  config,
  options,
  lib,
  pkgs,
  isDarwin,
  ...
}:
with lib;
with lib.my;
let
  cfg = config.modules.editors.code;
in
{
  options.modules.editors.code = {
    enable = mkBoolOpt false;
  };

  config = mkIf cfg.enable (mkMerge [
    {
      home-manager.users.${config.user.name}.programs.vscode = {
        enable = true;
        package = pkgs.unstable.vscode.fhs;
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
    }

    # NixOS-specific configuration (Liveshare dependencies)
    (optionalAttrs (!isDarwin) {
      services.gnome.gnome-keyring.enable = true;
      programs.seahorse.enable = true;
      # FIXME if kde
      programs.ssh.askPassword = lib.mkForce "${pkgs.libsForQt5.ksshaskpass}/libexec/ksshaskpass";
      programs.dconf.enable = true;
    })
  ]);
}
