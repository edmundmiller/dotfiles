{
  config,
  lib,
  pkgs,
  ...
}:
with lib;
with lib.my;
let
  cfg = config.modules.shell.fish;
in
{
  options.modules.shell.fish = {
    enable = mkBoolOpt false;
  };

  config = mkIf cfg.enable {
    programs.fish.enable = true;

    environment.systemPackages = with pkgs; [
      fishPlugins.autopair
      # FIXME fishPlugins.async-prompt
      fishPlugins.colored-man-pages
      fishPlugins.done
      jq
      libnotify
      fishPlugins.fzf-fish
      fishPlugins.forgit
      fishPlugins.hydro
      fzf
      fishPlugins.github-copilot-cli-fish
      fishPlugins.grc
      grc
    ];
  };
}
