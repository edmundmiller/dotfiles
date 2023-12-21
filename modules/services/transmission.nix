{
  config,
  options,
  lib,
  my,
  ...
}:
with lib;
with lib.my; let
  cfg = config.modules.services.transmission;
in {
  options.modules.services.transmission = {enable = mkBoolOpt false;};

  config = mkIf cfg.enable {
    services.transmission = {
      enable = true;
      settings = {
        download-dir = "/data/media/downloads";
        incomplete-dir-enabled = true;
        ratio-limit = 0;
        ratio-limit-enabled = true;
        rpc-bind-address = "0.0.0.0";
        rpc-host-whitelist = "*";
        rpc-host-whitelist-enabled = true;
        rpc-whitelist = "127.0.0.1,192.168.*.*";
      };
      openRPCPort = true;
      openPeerPorts = true;
    };

    user.extraGroups = ["transmission"];
  };
}
