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
  cfg = config.modules.services.snap;
in {
  options.modules.services.snap = {enable = mkBoolOpt false;};
  imports = [inputs.nix-snapd.nixosModules.default];

  config = mkIf cfg.enable {
    services.snap.enable = true;
  };
}
