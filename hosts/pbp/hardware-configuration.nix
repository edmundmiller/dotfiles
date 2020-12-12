# Do not modify this file!  It was generated by ‘nixos-generate-config’
# and may be overwritten by future invocations.  Please make changes
# to /etc/nixos/configuration.nix instead.
{ config, lib, pkgs, inputs, modulesPath, ... }:

{
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
    (let
      nixos-hardware = builtins.fetchGit {
        url = "https://github.com/samueldr/wip-pinebook-pro";
        ref = "feature/gfx-u-boot";
        rev = "4fe4f4a45db76a38f1e68c7c86bdb64b8cc457c7";
      };
    in "${nixos-hardware}/pinebook_pro.nix")
  ];

  boot.initrd.availableKernelModules = [ "nvme" "usbhid" ];
  boot.initrd.kernelModules = [ ];
  boot.kernelModules = [ ];
  boot.extraModulePackages = [ ];

  ## CPU
  nix.maxJobs = lib.mkDefault 6;
  powerManagement.cpuFreqGovernor = lib.mkDefault "ondemand";

  fileSystems."/" = {
    device = "/dev/disk/by-uuid/44444444-4444-4444-8888-888888888888";
    fsType = "ext4";
  };

  fileSystems."/home" = {
    device = "/dev/disk/by-uuid/9520482a-8ccb-460c-9fd8-49ab06979398";
    fsType = "ext4";
    options = [ "nofail" ];
  };
}
