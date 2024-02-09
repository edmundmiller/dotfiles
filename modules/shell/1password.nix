{
  config,
  options,
  pkgs,
  lib,
  ...
}:
with lib;
with lib.my; let
  cfg = config.modules.shell.bitwarden;
in {
  options.modules.shell."1password" = with types; {
    enable = mkBoolOpt false;
    config = mkOpt attrs {};
  };

  config = mkIf cfg.enable {
    # user.packages = with pkgs; [
    # ];

    programs._1password.enable = true;
    programs._1password-gui.enable = true;
    programs._1password-gui.polkitPolicyOwners = ["emiller"];
  };
}
