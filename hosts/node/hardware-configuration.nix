{ ... }: {
  imports = [ <nixpkgs/nixos/modules/profiles/qemu-guest.nix> ];

  boot.initrd.availableKernelModules =
    [ "ata_piix" "uhci_hcd" "virtio_pci" "sr_mod" "virtio_blk" ];
  boot.initrd.kernelModules = [ ];
  boot.kernelModules = [ ];
  boot.extraModulePackages = [ ];

  boot.loader.grub.device = "/dev/vda";
  boot.loader.grub.enable = true;
  boot.loader.grub.version = 2;

  fileSystems."/" = {
    device = "/dev/disk/by-uuid/2ecca2ba-fc5d-4a48-815c-3882a68e12c0";
    fsType = "ext4";
  };

  swapDevices =
    [{ device = "/dev/disk/by-uuid/0b69e520-f338-4586-ae1d-1a89ce0126bb"; }];

}
