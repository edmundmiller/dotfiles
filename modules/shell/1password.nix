{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:
with lib;
with lib.my; let
  cfg = config.modules.shell."1password";
in {
  options.modules.shell."1password" = {
    enable = mkBoolOpt false;
  };

  imports = [inputs._1password-shell-plugins.nixosModules.default];
  config = mkIf cfg.enable {
    # user.packages = with pkgs; [
    # ];

    programs._1password.enable = true;
    programs._1password-gui.enable = true;
    programs._1password-gui.polkitPolicyOwners = ["emiller"];

    programs._1password-shell-plugins = {
      enable = true;
      plugins = with pkgs; [
        unstable.gh # if shell/git
        awscli2
        # cachix
        unstable.pulumi-bin
      ];
    };
    programs.zsh = {
      enable = true;
    };
  };
}
