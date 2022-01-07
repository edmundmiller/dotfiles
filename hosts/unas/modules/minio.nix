{ config, lib, pkgs, ... }:

{
  modules.services.minio.enable = true;

  services.minio = {
    dataDir = [ "/data/minio" ];
    package = pkgs.unstable.minio;
    rootCredentialsFile = config.age.secrets.minio-rootCredentials.path;
  };
}
