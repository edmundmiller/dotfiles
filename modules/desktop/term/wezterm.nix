# modules/desktop/term/wezterm.nix
{
  config,
  lib,
  inputs,
  pkgs,
  ...
}:
with lib;
with lib.my;
let
  cfg = config.modules.desktop.term.wezterm;
in
{
  options.modules.desktop.term.wezterm = {
    enable = mkBoolOpt false;
  };

  config = mkIf cfg.enable {
    home-manager.users.${config.user.name}.programs.wezterm = {
      enable = true;
      package = inputs.wezterm.packages."${pkgs.stdenv.hostPlatform.system}".default;
      # default_prog = { "zsh", "--login", "-c", "tmux attach -t dev || tmux new -s dev" },
    };
    # TODO Waiting for config to stablize
    # home.configFile = {
    #   "wezterm/wezterm.lua".source = "${configDir}/wezterm/wezterm.lua";
    # };
  };
}
