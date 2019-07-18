{ config, lib, pkgs, ... }:

{
  fileSystems."/" = {
    device = "/dev/disk/by-uuid/89283f14-0274-43a8-96c4-89504b915a94";
    fsType = "ext4";
  };

  fileSystems."/boot" = {
    device = "/dev/disk/by-uuid/929F-F5A0";
    fsType = "vfat";
  };

  fileSystems."/data" = {
    device = "/dev/disk/by-label/data";
    fsType = "ext4";
  };

  swapDevices =
  [{ device = "/dev/disk/by-uuid/43303cfb-71b6-4fb7-b34c-7a0979312d2c"; }];
}
