{ config, pkgs, ... }:

{
  home.packages = with pkgs; [
    htop firefox rxvt_unicode networkmanagerapplet dunst libnotify mpv pass
    rofi-pass discord gimp tldr bat pavucontrol xclip gibo spotify nmap units
    binutils ffmpeg tetex obs-studio okular maim editorconfig-core-c
    keybase keybase-gui dropbox
    conda
    python37
    gcc
    i3lock-fancy sxhkd

    # C
    clangStdenv
    # haskell
    cabal-install cabal2nix haskellPackages.styx ghc hlint
    haskellPackages.hindent
    # (pkgs.haskellPackages.callCabal2nix "fullwidth" ~/projects/fullwidth {})
    # (pkgs.haskellPackages.callCabal2nix "polishnt" ~/projects/polishnt {})
  ];

  nixpkgs.config.allowUnfree = true;

  programs = {
    emacs.enable = true;

    git = {
      enable = true;
      userName = "Edmund Miller";
      userEmail = "edmund.a.miller@protonmail.com";
      extraConfig = ''
      [github]
      user = emiller88
      '';
    };

    rofi = {
      enable = true;
      extraConfig = ''
      rofi.modi: window,run,ssh,combi
      rofi.ssh-client: mosh
      rofi.ssh-command: {terminal} -e "{ssh-client} {host}"
      rofi.combi-modi: window,drun,ssh
      '';
      terminal = "urxvt";
      theme = "Arc-Dark";
    };

    # Let Home Manager install and manage itself.
    home-manager.enable = true;
  };

  services.polybar = {
    enable = true;
    config = {
      colors = {
        fg = "#ff0000";
        modfg = "#eff0eb";
        alt = "#00ff00";
        alt2 = "#0000ff";
        bg = "#282a36";
        white = "#eff0eb";
        gray = "#585858";
        black = "#282a36";
        red = "#ff5c57";
        blue = "#57c7ff";
        yellow = "#f3f99d";
        green = "#5af78e";
      };

      "bar/bottom" = {
        bottom = true;
        fixed-center = true;
        border-size = 0;
        wm-restack = "bspwm";

        width = "100%";
        height = 35;
        radius = 0;

        padding-left = 2;
        padding-right = 2;
        tray-position = "left";

        modules-right = "battery bspwm";
        modules-center = "date";
        modules-left = "cpu memory";
        separator = "     ";

        background = "\${colors.bg}";
        foreground = "\${colors.modfg}";

        font-0 = "Iosevka:weight=regular:size=15;3";
        font-1 = "FontAwesome:size=10;3";
      };

      "module/battery" = {
        type = "internal/battery";
        battery = "BAT1";
        adapter = "ACAD";

        format-charging = "<animation-charging> <label-charging>";
        format-charging-underline = "\${colors.green}";
        format-charging-padding = 1;

        format-discharging = "<ramp-capacity> <label-discharging>";
        format-discharging-underline = "\${colors.yellow}";
        format-discharging-padding = 1;

        format-full = "  <label-full>";
        format-full-underline = "\${self.format-charging-underline}";
        format-full-overline = "\${self.format-charging-underline}";
        format-full-padding = 1;

        ramp-capacity-0 = "";
        ramp-capacity-1 = "";
        ramp-capacity-2 = "";
        ramp-capacity-foreground = "\${colors.white}";

        animation-charging-0 = "";
        animation-charging-1 = "";
        animation-charging-2 = "";
        animation-charging-3 = "";
        animation-charging-4 = "";
        animation-charging-foreground = "\${colors.white}";
        animation-charging-framerate = 500;
      };

      "module/bspwm" = {
        type = "internal/bspwm";
        format = "<label-mode> <label-state>";
        index-sort = true;

        label-focused = "[%name%]";

        label-occupied = " %name% ";

        label-urgent = " %name% ";
        label-urgent-background = "\${colors.red}";

        label-empty = " %name% ";
        label-empty-foreground = "#55";

        # label-unfocused = "%index%";
        # label-unfocused-padding = 1;

        # label-urgent = "%index%";
        # label-urgent-background = "\${colors.red}";
        # label-urgent-padding = 1;

        # label-visible = "%index%";
        # label-visible-padding = 1;
      };


      "module/date" = {
        type = "internal/date";
        date-alt = "%A   %H:%M ";
        date = "%A %y/%m/%d   %H:%M:%S";
        interval = 1;

        format-foreground = "\${colors.blue}";
      };

      "module/cpu" = {
        format-label = "internal/cpu";

        format = "<label>";

        ramp-coreload-0 = "▁";
        ramp-coreload-1 = "▂";
        ramp-coreload-2 = "▃";
        ramp-coreload-3 = "▄";
        ramp-coreload-4 = "▅";
        ramp-coreload-5 = "▆";
        ramp-coreload-6 = "▇";
        ramp-coreload-7 = "█";
        ramp-coreload-underline = "\${colors.fg}";

        type = "internal/cpu";
        interval = 2;
        label = " %percentage%%";

        label-foreground = "\${colors.red}";
      };

      "module/memory" = {
        type = "internal/memory";
        interval = 2;

        label = " %gb_used%/%gb_total%";
        label-foreground = "\${colors.yellow}";
      };
    };
    script = "polybar bottom &";
  };
}
