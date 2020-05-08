# modules/dev/godot.nix --- https://godotengine.org/

{ config, options, lib, pkgs, ... }:
with lib; {
  options.modules.dev.godot = {
    enable = mkOption {
      type = types.bool;
      default = false;
    };
  };

  config = mkIf config.modules.dev.godot.enable {
    my.packages = with pkgs; [ godot ];
  };
}
