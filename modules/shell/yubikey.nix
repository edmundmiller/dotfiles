{
  config,
  pkgs,
  lib,
  ...
}:
with lib;
with lib.my;
let
  cfg = config.modules.shell.yubikey;
in
{
  options.modules.shell.yubikey = {
    enable = mkBoolOpt false;
  };

  config = mkIf cfg.enable {
    user.packages = with pkgs; [
      age-plugin-yubikey
      yubikey-manager-qt
      yubikey-manager
      yubikey-personalization
    ];

    services.udev.packages = [
      pkgs.yubikey-personalization
      pkgs.libu2f-host
    ];
    # Needed for age-plugin-yubikey
    # TODO mkIf (config.modules.shell.age.enable == true) {
    services.pcscd.enable = true;
  };
}
