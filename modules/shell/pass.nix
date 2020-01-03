{ config, lib, pkgs, ... }:

{
  environment = {
    systemPackages = with pkgs; [
      (pass.withExtensions
        (exts: [ exts.pass-otp exts.pass-genphrase exts.pass-import ]))
      (lib.mkIf (config.services.xserver.enable) rofi-pass)
    ];

    # HACK Have to symlink to ~/.password-store for mail
    variables.PASSWORD_STORE_DIR = "$HOME/.secrets/password-store";
  };
}
