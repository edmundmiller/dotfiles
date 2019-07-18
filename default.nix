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
      grub.useOSProber = true;
      efi.canTouchEfiVariables = true;
    };
    cleanTmpDir = true;
    plymouth.enable = true;
  };

  nixpkgs.config.allowUnfree = true;

  # nixpkgs.overlays = [
  #   (import ./overlays/lorri.nix)
  # ];

  environment = {
    systemPackages = with pkgs; [ coreutils git wget vim gnupg unzip bc (ripgrep.override {withPCRE2 = true;})];
    variables = {
      XDG_CONFIG_HOME = "$HOME/.config";
      XDG_CACHE_HOME = "$HOME/.cache";
      XDG_DATA_HOME = "$HOME/.local/share";
      XDG_BIN_HOME = "$HOME/.local/bin";
      # GTK2_RC_FILES = "$HOME/.config/gtk-2.0/gtkrc";
    };
    shellAliases = {
      q = "exit";
      clr = "clear";
      sudo = "sudo ";
    };
  };

  time.timeZone = "America/Chicago";

  # Block well known bad hosts
  networking.extraHosts = builtins.readFile (builtins.fetchurl {
    name = "blocked_hosts.txt";
    url =
    "http://pgl.yoyo.org/adservers/serverlist.php?hostformat=hosts&showintro=0&mimetype=plaintext";
  });

  nix.trustedUsers = [ "root" "@wheel" ];
  nix.nixPath = options.nix.nixPath.default ++ [ "config=${./config}" ];
  users.users.emiller = {
    # home = "/home/emiller";
    isNormalUser = true;
    uid = 1000;
    extraGroups = [ "wheel" "video" "networkmanager" ];
    shell = pkgs.zsh;
    openssh = { authorizedKeys.keys = [ "/home/emiller/.ssh/id_rsa" ]; };
  };

  home-manager.users.emiller = {
    xdg.enable = true;
    home.file."bin" = {
      source = ./bin;
      recursive = true;
    };
  };

  programs.gnupg.agent = {
    enable = true;
    enableSSHSupport = true;
  };

  # This value determines the NixOS release with which your system is to be
  # compatible, in order to avoid breaking some software such as database
  # servers. You should change this only after NixOS release notes say you
  # should.
  system.stateVersion = "19.03"; # Did you read the comment?
}
