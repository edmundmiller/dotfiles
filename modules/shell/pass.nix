{ config, lib, pkgs, ... }:

{
  environment = {
    systemPackages = with pkgs; [
      (pass.withExtensions
      (exts: [ exts.pass-otp exts.pass-genphrase ext.pass-import ]))
      (lib.mkIf (config.services.xserver.enable) rofi-pass)
    ];
  };
}
