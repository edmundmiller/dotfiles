{
  config,
  lib,
  ...
}:
with lib; {
  networking.hosts = let
    hostConfig = {
      "192.168.1.99" = ["framework"];
      "192.168.1.88" = ["meshify"];
      "192.168.1.101" = ["unas"];
    };
    hosts = flatten (attrValues hostConfig);
    hostName = config.networking.hostName;
  in
    mkIf (builtins.elem hostName hosts) hostConfig;

  ## Location config
  time.timeZone = lib.mkDefault "America/Chicago";
  i18n.defaultLocale = lib.mkDefault "en_US.UTF-8";
  # For redshift, mainly
  location =
    if config.time.timeZone == "America/Chicago"
    then {
      latitude = 32.9837;
      longitude = -96.752;
    }
    else {};

  # So the bitwarden CLI knows where to find my server.
  modules.shell.bitwarden.config.server = "bitwarden.com";
}
