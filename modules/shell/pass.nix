{ config, lib, pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    (pass.withExtensions (ext:
    [ # Base pass secret mgr + extensions
      ext.pass-import # import from other password managers
    ]))
    rofi-pass
  ];
}
