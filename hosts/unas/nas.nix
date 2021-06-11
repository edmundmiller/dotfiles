{ config, lib, pkgs, ... }:

{

  ## NAS
  fileSystems."/data/nfs/longhorn" = {
    device = "datatank/backup/longhorn";
    fsType = "zfs";
  };

  fileSystems."/srv/nfs/longhorn" = {
    device = "/data/nfs/longhorn";
    options = [ "bind" ];
  };

  fileSystems."/data/nfs/configs" = {
    device = "datatank/nfs/configs";
    fsType = "zfs";
  };

  fileSystems."/srv/nfs/configs" = {
    device = "/data/nfs/configs";
    options = [ "bind" ];
  };

  fileSystems."/data/media/books" = {
    device = "datatank/nfs/media/books";
    fsType = "zfs";
  };

  fileSystems."/srv/nfs/books" = {
    device = "/data/media/books";
    options = [ "bind" ];
  };

  fileSystems."/data/media/mail" = {
    device = "datatank/nfs/media/mail";
    fsType = "zfs";
  };

  fileSystems."/srv/nfs/mail" = {
    device = "/data/media/mail";
    options = [ "bind" ];
  };

  fileSystems."/data/backup/google" = {
    device = "datatank/backup/google";
    fsType = "zfs";
  };

  fileSystems."/data/backup/moni" = {
    device = "datatank/backup/moni";
    fsType = "zfs";
  };

  fileSystems."/data/media/music" = {
    device = "datatank/nfs/media/music";
    fsType = "zfs";
  };

  fileSystems."/srv/nfs/music" = {
    device = "/data/media/music";
    options = [ "bind" ];
  };

  fileSystems."/data/media/photos" = {
    device = "datatank/nfs/media/photos";
    fsType = "zfs";
  };

  fileSystems."/srv/nfs/photos" = {
    device = "/data/media/photos";
    options = [ "bind" ];
  };

  fileSystems."/data/media/video" = {
    device = "datatank/nfs/media/video";
    fsType = "zfs";
  };

  fileSystems."/srv/nfs/video" = {
    device = "/data/media/video";
    options = [ "bind" ];
  };

  networking.firewall.allowedTCPPorts = [ 2049 ];
  services.nfs.server = {
    enable = true;
    exports = ''
      /srv/nfs/longhorn      *(rw,nohide,insecure,no_subtree_check)
      /srv/nfs/configs       *(rw,nohide,insecure,no_subtree_check)
      /srv/nfs/books         *(rw,nohide,insecure,no_subtree_check)
      /srv/nfs/mail          *(rw,nohide,insecure,no_subtree_check)
      /srv/nfs/music         *(rw,nohide,insecure,no_subtree_check)
      /srv/nfs/photos        *(rw,nohide,insecure,no_subtree_check)
      /srv/nfs/video         *(rw,nohide,insecure,no_subtree_check)
    '';
  };
}