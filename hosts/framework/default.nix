# Framework -- my laptop

{ lib, pkgs, ... }: {
  imports = [ ../home.nix ./hardware-configuration.nix ./autorandr.nix ];

  modules = {
    desktop = {
      bspwm.enable = true;

      apps.rofi.enable = true;
      apps.discord.enable = true;

      browsers = {
        default = "firefox";
        firefox.enable = true;
        qutebrowser.enable = true;
      };

      media = {
        documents.enable = true;
        mpv.enable = true;
        ncmpcpp.enable = true;
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
      sensors.enable = true;
    };
    dev = {
      cc.enable = true;
      nixlang.enable = true;
      python.enable = true;
      R.enable = true;
    };

    shell = {
      bitwarden.enable = true;
      direnv.enable = true;
      git.enable = true;
      gnupg.enable = true;
      pass.enable = true;
      tmux.enable = true;
      zsh.enable = true;
    };

    services = {
      docker.enable = true;
      keybase.enable = true;
      mpd.enable = true;
      ssh.enable = true;
      syncthing.enable = true;
      tailscale.enable = true;
    };

    theme.active = "alucard";
  };

  programs.ssh.startAgent = true;
  services.openssh.startWhenNeeded = true;

  networking.networkmanager.enable = true;

  time.timeZone = "America/Chicago";

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
          dataset = "datatank/backup/framework";
          presend =
            "${pkgs.curl}/bin/curl -m 10 --retry 5 https://hc-ping.com/bfadc7f9-92d5-4d23-b2b7-a1f39a550f41/start";
          postsend =
            "${pkgs.curl}/bin/curl -m 10 --retry 5 https://hc-ping.com/bfadc7f9-92d5-4d23-b2b7-a1f39a550f41";
        };
      };
    };
  };
}
