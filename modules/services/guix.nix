{
  options,
  config,
  lib,
  pkgs,
  inputs,
  ...
}:
with lib;
with lib.my; let
  cfg = config.modules.services.guix;
in {
  imports = [inputs.guix.nixosModules.guix];
  options.modules.services.guix = {enable = mkBoolOpt false;};

  config = mkIf cfg.enable {
    nixpkgs.overlays = [inputs.guix.overlay];

    services.guix.enable = true;
  };
}
