{ config, lib, pkgs, ... }:

{
  modules.services.paperless.enable = true;

  services.paperless = {
    address = "0.0.0.0";
    mediaDir = "/data/media/docs/paperless";
    consumptionDir = "/data/media/docs/consume";
    passwordFile = config.age.secrets.paperless-adminCredentials.path;
  };
}
