{
  config,
  lib,
  ...
}:
with lib;
with lib.my; let
  cfg = config.modules.shell."1password";
in {
  options.modules.shell."1password" = {
    enable = mkBoolOpt false;
  };

  config = mkIf cfg.enable {
    # user.packages = with pkgs; [
    # ];

    programs._1password.enable = true;
    programs._1password-gui.enable = true;
    programs._1password-gui.polkitPolicyOwners = ["emiller"];
  };
}
