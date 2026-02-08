{
  config,
  lib,
  pkgs,
  ...
}:
with builtins;
with lib;
{
  networking.extraHosts = ''
    192.168.1.1   router.home

    # Hosts
    192.168.1.88   meshify.home
    192.168.1.101  unas.home
    192.168.1.144  nuc.home

    # Block garbage
    ${optionalString config.services.xserver.enable (readFile "${pkgs.stevenblack-blocklist}/hosts")}
  '';

  ## Location config
  time.timeZone = mkDefault "America/Chicago";
  i18n.defaultLocale = mkDefault "en_US.UTF-8";
  # For redshift, mainly
  location =
    if config.time.timeZone == "America/Chicago" then
      {
        latitude = 32.983;
        longitude = -96.752;
      }
    else
      { };

  # So the bitwarden CLI knows where to find my server.
  modules.shell.bitwarden.config.server = "bitwarden.com";

  # HACK https://github.com/danth/stylix/issues/200
  # Disabled for headless servers to avoid dconf/GTK dependencies
  # stylix.image = ../modules/themes/functional/config/wallpaper.png;
}
