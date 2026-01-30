{
  config,
  lib,
  pkgs,
  ...
}:
with lib;
with lib.my;
let
  cfg = config.modules.hardware.printing;
in
{
  options.modules.hardware.printing = {
    enable = mkBoolOpt false;
  };

  config = mkIf cfg.enable {
    services.printing.enable = true;
    services.printing.drivers = [ pkgs.brlaser ];
    # Network discovery
    services.avahi.enable = true;
    services.avahi.nssmdns4 = true;
  };
}
