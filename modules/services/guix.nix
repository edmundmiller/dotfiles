{ config, options, pkgs, lib, ... }:
with lib; {
  imports = [ ./guix-service.nix ];
  options.modules.services.guix = {
    enable = mkOption {
      type = types.bool;
      default = false;
    };
  };

  config =
    mkIf config.modules.services.guix.enable { services.guix.enable = true; };
}
