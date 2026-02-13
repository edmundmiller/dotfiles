{
  config,
  inputs,
  lib,
  pkgs,
  isDarwin,
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

  imports = optionals (!isDarwin) [ inputs.op-shell-plugins.nixosModules.default ];

  config = mkIf cfg.enable (mkMerge [
    {
      programs._1password.enable = true;
      programs._1password-gui.enable = !isDarwin;

      environment.etc = {
        "1password/custom_allowed_browsers" = {
          text = ''
            .floorp-wrapped
            floorp
            .zen-wrapped
          '';
        }
        // (if !isDarwin then { mode = "0755"; } else { });
      };

      programs.zsh = {
        enable = true;
      };
    }

    # NixOS-specific configuration
    (optionalAttrs (!isDarwin) {
      programs._1password-gui.polkitPolicyOwners = [ "emiller" ];

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
    })
  ]);
}
