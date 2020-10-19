{ options, config, lib, pkgs, inputs, ... }:

with lib;
with lib.my;
let cfg = config.modules.services.guix;
in {
  options.modules.services.guix = { enable = mkBoolOpt false; };

  config = mkIf cfg.enable {
    nixpkgs.overlays = [ inputs.guix.overlay ];

    environment.systemPackages = with pkgs; [ guix ];
  };
}
