{ config, options, lib, pkgs, ... }:

with lib; {
  options.modules.desktop.gaming.steam = {
    enable = mkOption {
      type = types.bool;
      default = false;
    };
  };

  config = mkIf config.modules.desktop.gaming.steam.enable {
    my.packages = with pkgs; [
      steam
      # Get steam to keep its garbage out of $HOME
      # FIXME
      # (writeScriptBin "steam" ''
      #   #!${stdenv.shell}
      #   HOME="$XDG_DATA_HOME/steamlib" exec ${steam}/bin/steam "$@"
      # '')
      # for GOG and humblebundle games
      (writeScriptBin "steam-run" ''
        #!${stdenv.shell}
        HOME="$XDG_DATA_HOME/steamlib" exec ${steam-run-native}/bin/steam-run "$@"
      '')
      xboxdrv # driver for 360 controller
    ];

    hardware.opengl.driSupport32Bit = true;
    # hardware.opengl.extraPackages32 = with pkgs.pkgsi686Linux; [ libva ];
    # hardware.opengl.extraPackages = with pkgs; [ libva ];
    hardware.pulseaudio.support32Bit = true;
    hardware.steam-hardware.enable = true;
  };
}
