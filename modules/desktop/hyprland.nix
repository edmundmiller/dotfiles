{ options, config, lib, pkgs, ... }:

with lib;
with lib.my;
let cfg = config.modules.desktop.hyprland;
in {
  options.modules.desktop.hyprland = { enable = mkBoolOpt false; };

  config = mkIf cfg.enable {
    programs.hyprland.enable = true;
    programs.hyprland.xwayland.hidpi = true;
  };
}
