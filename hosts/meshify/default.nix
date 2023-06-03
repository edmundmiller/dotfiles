{
  lib,
  pkgs,
  ...
}: {
  imports = [../home.nix ./hardware-configuration.nix];

  modules = {
    desktop = {
      hyprland.enable = true;

      apps.rofi.enable = true;
      apps.discord.enable = true;
      apps.evolution.enable = true;
      apps.weechat.enable = true;

      browsers = {
        default = "firefox";
        firefox.enable = true;
      };

      gaming.steam.enable = true;
      gaming.steam.hardware.enable = true;

      media = {
        documents.enable = true;
        # graphics.enable = true;
        mpv.enable = true;
        ncmpcpp.enable = true;
        recording.enable = true;
      };
      term = {
        default = "wezterm";
        wezterm.enable = true;
      };
    };

    editors = {
      default = "nvim";
      code.enable = true;
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
      printing.enable = true;
      sensors.enable = true;
    };
    dev = {
      cc.enable = true;
      java.enable = true;
      julia.enable = true;
      nixlang.enable = true;
      node.enable = true;
      node.enableGlobally = true;
      python.enable = true;
      R.enable = true;
      rust.enable = true;
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
      mpd.scrobbling.enable = true;
      ssh.enable = true;
      syncthing.enable = true;
      tailscale.enable = true;
    };

    theme.active = "functional";
  };

  programs.ssh.startAgent = true;
  services.openssh.startWhenNeeded = true;

  networking.hostId = "3b848ba1";
  networking.networkmanager.enable = true;

  time.timeZone = "America/Chicago";

  home-manager.users.emiller.wayland.windowManager.sway = {
    extraOptions = ["--debug" "--unsupported-gpu"];
    extraSessionCommands = ''
      # export SDL_VIDEODRIVER=wayland
      # needs qt5.qtwayland in systemPackages
      # export QT_QPA_PLATFORM=wayland
      # export QT_WAYLAND_DISABLE_WINDOWDECORATION="1"
      # Fix for some Java AWT applications (e.g. Android Studio),
      # use this if they aren't displayed properly:
      # export _JAVA_AWT_WM_NONREPARENTING=1
      export WLR_NO_HARDWARE_CURSORS=1
    '';
  };

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
          presend = "${pkgs.curl}/bin/curl -m 10 --retry 5 https://hc-ping.com/9568367d-ab78-46e8-8301-82a3c61b9595/start";
          postsend = "${pkgs.curl}/bin/curl -m 10 --retry 5 https://hc-ping.com/9568367d-ab78-46e8-8301-82a3c61b9595";
        };
      };
    };
  };
}
