{ config, lib, pkgs, ... }:

{
  modules.services.minio.enable = true;

  services.minio = {
    dataDir = [ "/data/minio" ];
    package = pkgs.unstable.minio;
  };
}
