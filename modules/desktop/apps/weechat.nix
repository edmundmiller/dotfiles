{ config, options, lib, pkgs, ... }:

with lib;
with lib.my;
let cfg = config.modules.desktop.apps.weechat;
in {
  options.modules.desktop.apps.weechat = { enable = mkBoolOpt false; };

  config = mkIf cfg.enable {
    user.packages = with pkgs; [
      # If not installed from unstable, Weechat will sometimes soft-lock itself
      # on a "there's an update for weechat" screen.
      weechat
    ];
  };
}
