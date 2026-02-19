{
  config,
  pkgs,
  lib,
  ...
}:
with lib;
with lib.my;
let
  cfg = config.modules.shell.sesh;
in
{
  options.modules.shell.sesh = with types; {
    enable = mkBoolOpt false;
  };

  config = mkIf cfg.enable {
    # almonk/sesh — zellij split with AI tool + lazygit
    # Shell function lives in config/sesh/aliases.zsh (auto-sourced by zsh module)
    user.packages = with pkgs; [
      zellij
    ];
  };
}
