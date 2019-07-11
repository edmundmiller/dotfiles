# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ config, pkgs, ... }:

{
  imports = [
    ./machines/omen.nix
    ./services/default.nix
    ./modules/steamcontroller.nix
    ./modules/shell.nix
  ];

  # Use the systemd-boot EFI boot loader.
  boot = {
    loader = {
      systemd-boot.enable = true;
      grub.useOSProber = true;
      efi.canTouchEfiVariables = true;
    };
  };

  fileSystems."/data" = {
    device = "/dev/disk/by-label/data";
    fsType = "ext4";
  };

  swapDevices =
  [{ device = "/dev/disk/by-uuid/43303cfb-71b6-4fb7-b34c-7a0979312d2c"; }];

  networking.hostName = "nixos-omen"; # Define your hostname.
  #networking.wireless.enable = true;  # Enables wireless support via wpa_supplicant.

  system.autoUpgrade = {
    enable = true;
    channel = "https://nixos.org/channels/nixos-unstable";
  };
  # Configure network proxy if necessary
  # networking.proxy.default = "http://user:password@proxy:port/";
  # networking.proxy.noProxy = "127.0.0.1,localhost,internal.domain";

  i18n = {
    consoleFont = "Lat2-Terminus16";
    consoleKeyMap = "us";
    defaultLocale = "en_US.UTF-8";
  };

  time.timeZone = "America/Chicago";

  nix.gc = {
    automatic = true;
    options = "--delete-older-than 30d";
  };

  environment.systemPackages = with pkgs; [
    wget
    vim
    git
    (ripgrep.override { withPCRE2 = true; })
    fd
    exa
    firefox
    gnupg
    fzf
    atool
    file
    tmux
    pv
    binutils
    openvpn
    xclip
    ((emacsPackagesNgGen emacs).emacsWithPackages
    (epkgs: [ epkgs.emacs-libvterm ]))
    openssl
    # home-manager
  ];

  fonts = {
    fontconfig.defaultFonts.monospace = [ "Iosevka" ];
    fonts = with pkgs; [
      fira-code-symbols
      iosevka
      noto-fonts
      symbola
      noto-fonts-cjk
      font-awesome_5
    ];
  };

  programs = {
    zsh = {
      enable = true;
      promptInit = "";
    };
    gnupg.agent = {
      enable = true;
      enableSSHSupport = true;
    };
  };

  # unfree
  nixpkgs.config.allowUnfree = true;
  # Open ports in the firewall.
  networking.firewall = {
    allowedTCPPorts = [ 27036 27037 ];
    allowedUDPPorts = [ 27031 27036 ];
  };
  # networking.firewall.enable = false;

  # Enable sound.
  sound.enable = true;
  hardware = {
    opengl.driSupport32Bit = true;
    pulseaudio = {
      enable = true;
      support32Bit = true;
    };
  };

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users = {
    defaultUserShell = pkgs.zsh;
    users = {
      emiller = {
        home = "/home/emiller";
        isNormalUser = true;
        description = "Edmund Miller";
        name = "emiller";
        uid = 1000;
        useDefaultShell = true;
        extraGroups =
        [ "wheel" "networkmanager" "docker" "transmission" "mpd" ];
        packages = [ pkgs.steam pkgs.steam-run ];
        openssh = { authorizedKeys.keys = [ "/home/emiller/.ssh/id_rsa" ]; };
      };
    };
    groups.vboxusers.members = [ "emiller" ];
  };

  # This value determines the NixOS release with which your system is to be
  # compatible, in order to avoid breaking some software such as database
  # servers. You should change this only after NixOS release notes say you
  # should.
  system.stateVersion = "19.03"; # Did you read the comment?

}
