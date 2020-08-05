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
      nixlang.enable = true;
      node.enable = true;
      python.enable = true;
      R.enable = true;
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
      keybase.enable = true;
      mpd.enable = true;
      pia.enable = true;
      ssh-agent.enable = true;
      syncthing.enable = true;
    };

    themes.fluorescence.enable = true;
  };

  time.timeZone = "America/Chicago";

  environment.systemPackages = with pkgs; [
    acpi
    xorg.xbacklight
    ledger-live-desktop
  ];
  powerManagement.powertop.enable = true;
}
