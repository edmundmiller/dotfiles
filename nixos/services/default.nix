{ config, lib, pkgs, ... }:

{
  imports = [ ./keybase.nix ./transmission.nix ];

  # services.autorandr = {
  #   enable = true;
  #   defaultTarget = "main";
  # };
  services = {
    emacs.defaultEditor = true;
    # Enable the OpenSSH daemon.
    openssh = {
      enable = true;
      startWhenNeeded = true;
    };

    printing.enable = true;
    gnome3.chrome-gnome-shell.enable = true;
    localtime.enable = true;
    dbus.packages = with pkgs; [ gnome3.dconf ];

    syncthing = {
      enable = true;
      openDefaultPorts = true;
      user = "emiller";
      dataDir = "/home/emiller/Sync";
      configDir = "/home/emiller/.config/syncthing";
    };

    mpd = {
      enable = true;
      musicDirectory = "/data/emiller/Music/";
      startWhenNeeded = true;
      extraConfig = ''
        input {
                plugin "curl"
        }

        audio_output {
            type        "pulse"
            name        "pulse audio"
        }

        audio_output {
            type        "fifo"
            name        "mpd_fifo"
            path        "/tmp/mpd.fifo"
            format      "44100:16:2"
        }
      '';
    };

    # Enable the X11 windowing system.
    xserver = {
      enable = true;
      layout = "us";
      xkbOptions = "caps:escape";
      videoDrivers = [ "nvidiaBeta" ];
      libinput = {
        enable = true;
        disableWhileTyping = true;
        tapping = false;
      };

      displayManager = {
        gdm.enable = true;
        gdm.wayland = false;
        # lightdm = {
        #   enable = true;
        #   greeters.gtk = {
        #     # extraConfig = ;
        #     cursorTheme.name = "Adwaita";
        #     cursorTheme.package = pkgs.gnome3.adwaita-icon-theme;
        #     iconTheme.name = "Adwaita";
        #     iconTheme.package = pkgs.gnome3.adwaita-icon-theme;
        #     theme.name = "Adwaita";
        #     theme.package = pkgs.gnome3.adwaita-icon-theme;
        #   };
        # };
      };
      # Gnome desktop
      # * Slightly more familiar than KDE for people who are used to working with Ubuntu
      # * Gnome3 works out of the box with xmonad
      desktopManager = {
        gnome3 = { enable = true; };

        # default = "xfce";
        xterm.enable = false;
        xfce = {
          enable = true;
          noDesktop = true;
          enableXfwm = false;
        };
      };

      windowManager = {
        default = "xmonad";
        xmonad = {
          enable = true;
          enableContribAndExtras = true;
          extraPackages = haskellPackages: [
            haskellPackages.xmonad-contrib
            haskellPackages.xmonad-extras
            haskellPackages.xmonad
          ];
        };
      };
    };
  };

  virtualisation = {
    docker.enable = true;
    docker.autoPrune.enable = true;
    virtualbox.host.enable = true;
  };
}
