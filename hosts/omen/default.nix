# Omen -- my laptop

{ lib, ... }: {
  imports = [ ../home.nix ./hardware-configuration.nix ./autorandr.nix ];

  modules = {
    desktop = {
      bspwm.enable = true;

      apps.rofi.enable = true;
      apps.discord.enable = true;
      apps.evolution.enable = true;

      browsers = {
        default = "firefox";
        firefox.enable = true;
      };

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
      bluetooth.enable = true;
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
      python.enable = true;
      R.enable = true;
    };

    shell = {
      direnv.enable = true;
      git.enable = true;
      gnupg.enable = true;
      pass.enable = true;
      tmux.enable = true;
      yubikey.enable = true;
      zsh.enable = true;
    };

    services = {
      # calibre.enable = true;
      docker.enable = true;
      keybase.enable = true;
      mpd.enable = true;
      # pia.enable = true;
      ssh.enable = true;
      syncthing.enable = true;
      transmission.enable = true;
    };

    theme.active = "alucard";
  };

  services.openssh.startWhenNeeded = true;

  networking.networkmanager.enable = true;

  time.timeZone = "America/Chicago";

  services.picom.backend = "xr_glx_hybrid";

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
          dataset = "datatank/backup/omen";
        };
      };
    };
  };
}
