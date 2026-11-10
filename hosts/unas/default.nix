# No u nas
{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:
{
  imports = [
    ../_server.nix
    ../_home.nix
    inputs.rex.nixosModules.default
    ./hardware-configuration.nix
    ./amp-orbs.nix
    ./nas.nix
    ./disko.nix

    ./backups.nix
    ./modules/time-machine.nix
    ./users.nix
  ];

  # Keep Rex state in /var/lib/rex and run terminals as the NAS user.
  services.rex = {
    enable = true;
    user = "emiller";
    group = "users";
    socketMode = "0600";
    tailscale = {
      enable = true;
      hostname = "unas-rex";
      # Admit tagged NUC clients; Tailscale ACLs remain the access boundary.
      allowTailnetMembers = true;
    };
  };

  ## Modules
  modules = {
    editors = {
      default = "nvim";
      vim.enable = true;
    };
    hardware = {
      fs = {
        enable = true;
        zfs.enable = false;
        ssd.enable = true;
      };
    };
    shell = {
      git.enable = true;
      zsh.enable = true;
    };
    services = {
      containers.enable = true;
      ssh.enable = true;
      syncthing.enable = true;
      tailscale.enable = true;
    };

    theme.active = "alucard";
  };

  time.timeZone = "America/Chicago";

  # Preserve the installed data-format and headless activation defaults.
  system.stateVersion = lib.mkForce "24.05";
  # No desktop session or dconf D-Bus service exists on this headless host.
  home-manager.users.emiller.dconf.enable = false;

  # Give offline recovery the built system's actual bootloader inputs.
  environment.etc."unas-recovery-boot.json".text = builtins.toJSON {
    inherit (config.boot.loader.systemd-boot) configurationLimit extraFiles extraEntries;
    esp = config.boot.loader.efi.efiSysMountPoint;
    xbootldr = config.boot.loader.systemd-boot.xbootldrMountPoint;
    efiBinary = "${config.systemd.package}/lib/systemd/boot/efi/systemd-boot${pkgs.stdenv.hostPlatform.efiArch}.efi";
  };

  # Keep runtime identities independent of the build machine's filesystem.
  age.identityPaths = lib.mkForce [
    "/home/emiller/.ssh/id_ed25519"
    "/etc/ssh/ssh_host_rsa_key"
    "/etc/ssh/ssh_host_ed25519_key"
  ];
  # Agenix needs the preserved home identity before stage-two activation.
  fileSystems."/home".neededForBoot = true;

  boot.kernelPackages = pkgs.linuxPackages;
  boot.supportedFilesystems = [ "btrfs" ];
  boot.kernel.sysctl."net.ipv4.ip_forward" = 1;

  environment.systemPackages = [ pkgs.btrfs-progs ];

  # The public flake must contain this layout before automatic upgrades resume.
  system.autoUpgrade.enable = lib.mkForce false;

  services.smartd.enable = true;
  # FIXME https://discourse.nixos.org/t/logrotate-config-fails-due-to-missing-group-30000/28501/7
  services.logrotate.checkConfig = false;
}
