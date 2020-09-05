{ config, options, pkgs, ... }:

{
  imports = [
    ../personal.nix # common settings
    ./hardware-configuration.nix
  ];

  modules = {
    desktop = {
      bspwm.enable = true;

      apps.rofi.enable = true;
      apps.discord.enable = true;
      apps.graphics.enable = true;

      term.default = "xst";
      term.alacritty.enable = true;
      term.st.enable = true;

      browsers.default = "qutebrowser";
      browsers.firefox.enable = true;
      browsers.qutebrowser.enable = true;

      gaming.steam.enable = true;
    };

    editors = {
      default = "nvim";
      emacs.enable = true;
      vim.enable = true;
    };

    dev = {
      cc.enable = true;
      clojure.enable = true;
      common-lisp.enable = true;
      nixlang.enable = true;
      node.enable = true;
      python.enable = true;
      R.enable = true;
      rust.enable = true;
    };

    media = { mpv.enable = true; };

    shell = {
      direnv.enable = true;
      git.enable = true;
      gnupg.enable = true;
      kubernetes.enable = true;
      mail.enable = true;
      ncmpcpp.enable = true;
      pass.enable = true;
      tmux.enable = true;
      ranger.enable = true;
      zsh.enable = true;
    };

    services = {
      calibre.enable = true;
      docker.enable = true;
      guix.enable = true;
      keybase.enable = true;
      mpd.enable = true;
      pia.enable = true;
      ssh-agent.enable = true;
      syncthing.enable = true;
      transmission.enable = true;
    };

    themes.functional.enable = true;
  };

  networking.hostId = "3b848ba1";
  networking.networkmanager.enable = true;

  time.timeZone = "America/Chicago";
  services.xserver.dpi = 186;

  # ZFS
  boot.supportedFilesystems = [ "zfs" ];
  boot.loader.grub.copyKernels = true;
  services.zfs.autoScrub.enable = true;
  services.zfs.trim.enable = true;
  services.znapzend = {
    enable = true;
    autoCreation = true;
    zetup = {
      "tank/user/home" = {
        plan = "1d=>1h,1m=>1d,1y=>1m";
        recursive = true;
        destinations.local = { dataset = "bigdata/backup"; };
      };
    };
  };
}
