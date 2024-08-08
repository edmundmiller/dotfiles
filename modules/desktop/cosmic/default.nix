{
  inputs,
  options,
  config,
  lib,
  pkgs,
  ...
}:
with lib;
with lib.my;
let
  cfg = config.modules.desktop.cosmic;
in
{
  options.modules.desktop.cosmic = {
    enable = mkBoolOpt false;
  };

  imports = [ inputs.nixos-cosmic.nixosModules.default ];
  config = mkIf cfg.enable {
    services.displayManager.cosmic-greeter.enable = true;
    services.desktopManager.cosmic.enable = true;
  };
}
