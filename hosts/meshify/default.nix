{ lib, ... }: {
  imports = [ ../personal.nix ./hardware-configuration.nix ];

  modules = {
    desktop = {
      bspwm.enable = true;

      apps.rofi.enable = true;
      apps.discord.enable = true;

      browsers = {
        default = "firefox";
        firefox.enable = true;
        nyxt.enable = true;
      };

      gaming.steam.enable = true;
      gaming.steam.hardware.enable = true;

      media = {
        documents.enable = true;
        graphics.enable = true;
        mpv.enable = true;
        ncmpcpp.enable = true;
        recording.enable = true;
      };
      term = {
        default = "xst";
        st.enable = true;
      };
    };

    editors = {
      default = "nvim";
      emacs.enable = true;
      vim.enable = true;
    };
    hardware = {
      audio.enable = true;
      ergodox.enable = true;
      fs = {
        enable = true;
        zfs.enable = true;
        ssd.enable = true;
      };
      nvidia.enable = true;
      sensors.enable = true;
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

    shell = {
      direnv.enable = true;
      git.enable = true;
      gnupg.enable = true;
      nnn.enable = true;
      pass.enable = true;
      tmux.enable = true;
      zsh.enable = true;
    };

    services = {
      docker.enable = true;
      guix.enable = true;
      keybase.enable = true;
      mpd.enable = true;
      ssh.enable = true;
      # ssh-agent.enable = true;
      syncthing.enable = true;
      transmission.enable = true;
    };

    theme.active = "functional";
  };

  programs.ssh.startAgent = true;
  services.openssh.startWhenNeeded = true;

  networking.hostId = "3b848ba1";
  networking.networkmanager.enable = true;

  time.timeZone = "America/Chicago";

  # hiDPI
  services.xserver.dpi = 192;
  fonts.fontconfig.hinting.enable = false;

  # znapzend
  systemd.services.znapzend.serviceConfig.User = lib.mkForce "emiller";
  services.znapzend = {
    enable = true;
    autoCreation = true;
    zetup = {
      "tank/user/home" = {
        plan = "1d=>1h,1m=>1d,1y=>1m";
        recursive = true;
        destinations.remote = {
          host = "unas";
          dataset = "datatank/backup/meshify";
        };
      };
    };
  };
}
