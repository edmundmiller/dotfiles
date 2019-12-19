{ config, pkgs, options, ... }:

{
  imports = [
    <nixpkgs/nixos/modules/installer/scan/not-detected.nix>
    <home-manager/nixos>
    /etc/nixos/hardware-configuration.nix
  ];

  boot = {
    loader = {
      systemd-boot.enable = true;
      efi.canTouchEfiVariables = true;
    };
    cleanTmpDir = true;
    plymouth.enable = true;
  };

  nix = {
    nixPath = options.nix.nixPath.default
    ++ [ "config=/etc/dotfiles/config" "packages=/etc/dotfiles/packages" ];
    autoOptimiseStore = true;
    trustedUsers = [ "root" "@wheel" ];
  };
  nixpkgs.config = {
    allowUnfree = true;

    packageOverrides = pkgs: {
      unstable = import <nixpkgs-unstable> { config = config.nixpkgs.config; };
    };
  };

  environment = {
    systemPackages = with pkgs; [
      # Just the bear necessities~
      libqalculate
      coreutils
      git
      killall
      unzip
      vim
      wget
      # Support for extra filesystems
      sshfs
      exfat
      ntfs3g
      hfsprogs
    ];
    variables = {
      XDG_CONFIG_HOME = "$HOME/.config";
      XDG_CACHE_HOME = "$HOME/.cache";
      XDG_DATA_HOME = "$HOME/.local/share";
      XDG_BIN_HOME = "$HOME/.local/bin";
    };
  };

  time.timeZone = "America/Chicago";

  # Block well known bad hosts
  networking.extraHosts = builtins.readFile (builtins.fetchurl {
    name = "blocked_hosts.txt";
    url =
    "http://pgl.yoyo.org/adservers/serverlist.php?hostformat=hosts&showintro=0&mimetype=plaintext";
  });

  users.users.emiller = {
    isNormalUser = true;
    uid = 1000;
    description = "Edmund Miller";
    extraGroups = [ "wheel" "video" ];
    shell = pkgs.zsh;
  };

  home-manager.users.emiller = {
    xdg.enable = true;
    home.file."bin" = {
      source = ./bin;
      recursive = true;
    };
  };

  networking.firewall.enable = true;

  # This value determines the NixOS release with which your system is to be
  # compatible, in order to avoid breaking some software such as database
  # servers. You should change this only after NixOS release notes say you
  # should.
  system.stateVersion = "19.03"; # Did you read the comment?
}
