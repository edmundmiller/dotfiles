{ config, options, lib, pkgs, inputs, ... }:

with lib;
with lib.my;
let cfg = config.modules.desktop.apps.evolution;
in {
  options.modules.desktop.apps.evolution = { enable = mkBoolOpt false; };

  config = mkIf cfg.enable {
    # https://github.com/NixOS/nixpkgs/pull/103135
    programs.evolution.enable = true;
    programs.evolution.plugins = [ pkgs.evolution-ews ];
    services.gnome.evolution-data-server.enable = true;
    services.gnome.gnome-keyring.enable = true;
    programs.seahorse.enable = true;
    programs.dconf.enable = true;
  };
}
