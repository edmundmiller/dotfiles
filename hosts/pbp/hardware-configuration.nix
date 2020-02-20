# Do not modify this file!  It was generated by ‘nixos-generate-config’
# and may be overwritten by future invocations.  Please make changes
# to /etc/nixos/configuration.nix instead.
{ config, lib, pkgs, ... }:

{
  imports = [
    <nixpkgs/nixos/modules/installer/scan/not-detected.nix>
    (let
      nixos-hardware = builtins.fetchGit {
        url = "https://github.com/emiller88/wip-pinebook-pro";
        ref = "suspend";
        rev = "2e1d0d6c813834a8d0c30c20e226caa33b586798";
      };
    in "${nixos-hardware}/pinebook_pro.nix")
  ];

  boot.initrd.availableKernelModules = [ ];
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

  # fileSystems."/home/emiller/src" = {
  #   device = "/dev/disk/by-uuid/9520482a-8ccb-460c-9fd8-49ab06979398";
  #   fsType = "ext4";
  # };
}