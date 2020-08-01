{ config, options, pkgs, ... }:

{
  imports = [
    ../personal.nix # common settings
    ./hardware-configuration.nix
    ./autorandr.nix
  ];

  modules = {
    desktop = {
      bspwm.enable = true;

      apps.rofi.enable = true;
      apps.discord.enable = true;

      term.default = "xst";
      term.st.enable = true;

      browsers.default = "firefox";
      browsers.firefox.enable = true;
    };

    editors = {
      default = "nvim";
      emacs.enable = true;
      vim.enable = true;
    };

    dev = {
      cc.enable = true;
      # nixlang.enable = true;
      node.enable = true;
      python.enable = true;
    };

    media = { mpv.enable = true; };

    shell = {
      aerc.enable = true;
      direnv.enable = true;
      git.enable = true;
      gnupg.enable = true;
      ncmpcpp.enable = true;
      pass.enable = true;
      tmux.enable = true;
      ranger.enable = true;
      yubikey.enable = true;
      zsh.enable = true;
    };

    services = {
      docker.enable = true;
      pia.enable = true;
      syncthing.enable = true;
    };

    themes.fluorescence.enable = true;
  };

  environment.systemPackages = [ pkgs.acpi pkgs.xorg.xbacklight ];
  programs.ssh.startAgent = true;
  networking.hostName = "pbp";
  networking.networkmanager.enable = true;

  time.timeZone = "America/Chicago";

  nixpkgs.config.allowUnsupportedSystem = true;
  nixpkgs.config.allowBroken = true;
  # NixOS wants to enable GRUB by default
  boot.loader.grub.enable = false;
  # Enables the generation of /boot/extlinux/extlinux.conf
  boot.loader.generic-extlinux-compatible.enable = true;
}
