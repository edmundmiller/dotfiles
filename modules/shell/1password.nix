{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:
with lib;
with lib.my;
let
  cfg = config.modules.shell."1password";
in
{
  options.modules.shell."1password" = {
    enable = mkBoolOpt false;
  };

  imports = [ inputs.op-shell-plugins.nixosModules.default ];
  config = mkIf cfg.enable {
    programs._1password.enable = true;
    programs._1password-gui.enable = true;
    programs._1password-gui.polkitPolicyOwners = [ "emiller" ];

    environment.etc = {
      "1password/custom_allowed_browsers" = {
        text = ''
          .floorp-wrapped
          floorp
          .zen-wrapped
        '';
        mode = "0755";
      };
    };

    programs._1password-shell-plugins = {
      enable = true;
      plugins = with pkgs; [
        unstable.gh # if shell/git
        awscli2
        # cachix
        unstable.pulumi-bin
        python3Packages.huggingface-hub
      ];
    };
    programs.zsh = {
      enable = true;
    };
  };
}
