# modules/desktop/apps/redshift.nix

{ config, lib, pkgs, ... }: {
  services.redshift.enable = true;

  # For redshift
  location = (if config.time.timeZone == "America/Chicago" then {
    latitude = 32.98576;
    longitude = -96.75009;
  } else
    { });
}
