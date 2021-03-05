{ config, options, lib, pkgs, ... }:

with lib;
with lib.my;
let cfg = config.modules.desktop.apps.mail;
in {

  options.modules.desktop.apps.mail = { enable = mkBoolOpt false; };

  config = mkIf cfg.enable { };
}
