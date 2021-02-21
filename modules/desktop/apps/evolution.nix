{ config, options, lib, pkgs, inputs, ... }:

with lib;
with lib.my;
let cfg = config.modules.desktop.apps.evolution;
in {
  options.modules.desktop.apps.evolution = { enable = mkBoolOpt false; };

  config = mkIf cfg.enable {
    programs.evolution.enable = true;
    programs.evolution.plugins = [ pkgs.evolution-ews ];
  };
}
