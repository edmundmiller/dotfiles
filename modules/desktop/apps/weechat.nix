{ config, options, lib, pkgs, ... }:

with lib;
with lib.my;
let
  cfg = config.modules.desktop.apps.weechat;
  weechat = pkgs.wrapWeechat pkgs.weechat-unwrapped {
    configure = { availablePlugins, ... }: {
      scripts = with pkgs; [
        weechatScripts.colorize_nicks
        weechatScripts.multiline
        weechatScripts.wee-slack
        weechatScripts.weechat-notify-send
        weechatScripts.weechat-autosort
      ];
    };
  };
in
{
  options.modules.desktop.apps.weechat = { enable = mkBoolOpt false; };

  config = mkIf cfg.enable { user.packages = with pkgs; [ weechat ]; };
}
