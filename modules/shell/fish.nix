{
  config,
  options,
  lib,
  pkgs,
  ...
}:
with lib;
with lib.my; let
  cfg = config.modules.shell.fish;
in {
  options.modules.shell.fish = {enable = mkBoolOpt false;};

  config = mkIf cfg.enable {
    programs.fish.enable = true;

    environment.systemPackages = with pkgs; [
      fishPlugins.done
      fishPlugins.fzf-fish
      fishPlugins.forgit
      fishPlugins.hydro
      fzf
      fishPlugins.grc
      grc
    ];
  };
}
