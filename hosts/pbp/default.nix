# Pinebook-pro --

{ ... }: {
  imports = [ ../personal.nix ./hardware-configuration.nix ];

  modules = {
    desktop = {
      bspwm.enable = true;

      apps.rofi.enable = true;

      browsers = {
        default = "firefox";
        firefox.enable = true;
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
      fs = {
        enable = true;
        ssd.enable = true;
      };
      sensors.enable = true;
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
      docker.enable = true;
      # keybase.enable = true;
      mpd.enable = true;
      ssh.enable = true;
      syncthing.enable = true;
      transmission.enable = true;
    };

    theme.active = "alucard";
  };

  services.openssh.startWhenNeeded = true;

  networking.networkmanager.enable = true;

  time.timeZone = "America/Chicago";

  # services.picom.backend = "xr_glx_hybrid";
}
