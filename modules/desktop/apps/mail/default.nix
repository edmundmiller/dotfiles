{ config, options, lib, pkgs, ... }:

with lib;
with lib.my;
let cfg = config.modules.desktop.apps.mail;
in {
  imports = [ ./aerc.nix ./davmail.nix ./imapfilter.nix ./mbsync.nix ];

  options.modules.desktop.apps.mail = { enable = mkBoolOpt false; };

  config = mkIf cfg.enable { };
}
