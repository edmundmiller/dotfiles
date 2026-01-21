{
  options,
  config,
  lib,
  pkgs,
  ...
}:
with lib;
with lib.my;
let
  cfg = config.modules.hardware.ergodox;
in
{
  options.modules.hardware.ergodox = {
    enable = mkBoolOpt false;
  };

  config = mkIf cfg.enable {
    user.packages = with pkgs; [
      teensy-loader-cli
      # QMK build environment for local firmware compilation
      qmk
      avrdude
      dfu-programmer
      dfu-util
    ];
    # 'teensyload FILE' to load a new config into the ergodox
    environment.shellAliases.teensyload = "sudo teensy-loader-cli -w -v --mcu=atmega32u4";
    # Make right-alt the compose key, so ralt+a+a = å or ralt+o+/ = ø
    services.xserver.xkb.options = "compose:ralt";
  };
}
