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
        zfs.enable = true;
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

  # Preserve the installed system's data-format defaults across upgrades.
  system.stateVersion = lib.mkForce "24.05";
  # Recovery deployments must not be replaced overnight by an older remote tree.
  system.autoUpgrade.enable = lib.mkForce false;
  # No desktop session or dconf D-Bus service exists on this headless host.
  home-manager.users.emiller.dconf.enable = false;

  # Give offline recovery the built system's actual bootloader inputs.
  environment.etc."unas-recovery-boot.json".text = builtins.toJSON {
    inherit (config.boot.loader.systemd-boot) configurationLimit extraFiles extraEntries;
    esp = config.boot.loader.efi.efiSysMountPoint;
    xbootldr = config.boot.loader.systemd-boot.xbootldrMountPoint;
    efiBinary = "${config.systemd.package}/lib/systemd/boot/efi/systemd-boot${pkgs.stdenv.hostPlatform.efiArch}.efi";
  };

  # The rescue connection must also work after booting the installed system.
  users.users.emiller.openssh.authorizedKeys.keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGJ64slBBRJVfH38s9zN6mlphbj/R0rrOfm91vgZEzkh blip@meshify"
  ];

  # Two older pools have the same name. Only these mirror members may satisfy
  # the datatank import; leave the 18 TB and 6 TB disks untouched.
  boot.zfs.pools.datatank.devNodes = "/dev/disk/unas-datatank";
  boot.zfs.forceImportRoot = false;
  boot.zfs.forceImportAll = false;
  services.udev.extraRules = ''
    SUBSYSTEM=="block", ENV{DEVTYPE}=="partition", ENV{ID_SERIAL}=="WDC_WD160EDGZ-11B2DA0_2PHTEHKT", ENV{ID_PART_ENTRY_NUMBER}=="1", SYMLINK+="disk/unas-datatank/mirror-1"
    SUBSYSTEM=="block", ENV{DEVTYPE}=="partition", ENV{ID_SERIAL}=="WDC_WD160EDGZ-11B2DA0_3HGZMWEN", ENV{ID_PART_ENTRY_NUMBER}=="1", SYMLINK+="disk/unas-datatank/mirror-2"
  '';

  boot.kernel.sysctl."net.ipv4.ip_forward" = 1;

  services.smartd.enable = true;
  # FIXME https://discourse.nixos.org/t/logrotate-config-fails-due-to-missing-group-30000/28501/7
  services.logrotate.checkConfig = false;

  # systemd.services.znapzend.serviceConfig.User = lib.mkForce "emiller";
  services.znapzend = {
    enable = true;
    autoCreation = true;
    zetup = {
      "zroot/user/home" = {
        plan = "1d=>1h,1m=>1d,1y=>1m";
        recursive = true;
        destinations.local = {
          dataset = "datatank/backup/unas";
          presend = "${pkgs.curl}/bin/curl -m 10 --retry 5 https://hc-ping.com/ccb26fbc-95af-45bb-b4e6-38da23db6893/start";
          postsend = "${pkgs.curl}/bin/curl -m 10 --retry 5 https://hc-ping.com/ccb26fbc-95af-45bb-b4e6-38da23db6893";
        };
      };
    };
  };
}
