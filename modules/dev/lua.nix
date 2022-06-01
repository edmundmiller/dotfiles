# modules/dev/lua.nix --- https://www.lua.org/
#
# I use lua for modding, awesomewm or Love2D for rapid gamedev prototyping (when
# godot is overkill and I have the luxury of avoiding JS). I write my Love games
# in moonscript to get around lua's idiosynchrosies. That said, I install love2d
# on a per-project basis.

{ config, options, lib, pkgs, ... }:

with lib;
with lib.my;
let cfg = config.modules.dev.lua;
in {
  options.modules.dev.lua = {
    enable = mkBoolOpt false;
    love2D.enable = mkBoolOpt false;
  };

  config = mkIf cfg.enable {
    user.packages = with pkgs; [
      lua
      luaPackages.moonscript
      (mkIf cfg.love2D.enable love2d)
    ];
  };
}
