{ options, config, lib, pkgs, ... }:

with lib;
with lib.my;
let cfg = config.modules.desktop.sway;
in {
  options.modules.desktop.sway = { enable = mkBoolOpt false; };

  config = mkIf cfg.enable {
    home-manager.users.emiller = {
      wayland.windowManager.sway.enable = true;
      programs.foot.enable = true;
      wayland.windowManager.sway.config = rec {
        modifier = "Mod4";
        terminal = "foot";
        focus.followMouse = "always";
        colors = let
          # from gruvbox image:
          red = "#cc241d";
          pink = "#d3869b";
          blue = "#458588";
          green = "#b8bb26";
          yellow = "#d79921";
          orange = "#fe8019";
          # bgcolor = "#2c2c2c";
          bgcolor = "#000000";
          _f = red;
        in {
          "focused" = {
            border = _f;
            background = _f;
            text = "#ffffff";
            indicator = "#ffffff";
            childBorder = _f;
          };
          "unfocused" = {
            border = bgcolor;
            background = bgcolor;
            text = "#888888";
            indicator = "#ffffff";
            childBorder = bgcolor;
          };
        };
        gaps = {
          inner = 2;
          outer = 2;
        };
        window.border = 4;
        window.titlebar = false;

        keybindings = lib.mkOptionDefault {
          "${modifier}+Return" = ''
            exec ${terminal} -e bash -c "(tmux ls | grep -qEv 'attached|scratch' && tmux at) || tmux"
          '';
          # "${modifier}+space" = "\${pkgs.dmenu}/bin/dmenu_path | \${pkgs.dmenu}/bin/dmenu | \${pkgs.findutils}/bin/xargs swaymsg exec --";
          "XF86AudioMute" = "exec pamixer --toggle-mute";
          "XF86AudioLowerVolume" = "exec pamixer -d 10";
          "XF86AudioRaiseVolume" = "exec pamixer -i 10";
        };
      };
      wayland.windowManager.sway.extraConfig = ''
        input "type:keyboard" {
            xkb_options caps:escape
        }
        output HDMI-A-1 disable
        output DP-2 disable
      '';

      services.swayidle = {
        enable = true;
        events = [
          {
            event = "before-sleep";
            command = "${pkgs.swaylock}/bin/swaylock";
          }
          {
            event = "lock";
            command = "lock";
          }
        ];
        timeouts = [{
          timeout = 300;
          command = "${pkgs.swaylock}/bin/swaylock -fF";
        }];
      };

      programs.swaylock.settings = {
        color = "808080";
        font-size = 24;
        indicator-idle-visible = false;
        indicator-radius = 100;
        line-color = "ffffff";
        show-failed-attempts = true;
      };

      # home.pointerCursor = {
      #   name = "Adwaita";
      #   package = pkgs.gnome.adwaita-icon-theme;
      #   size = 24;
      #   x11 = {
      #     enable = true;
      #     defaultCursor = "Adwaita";
      #   };
      # };

      home.packages = with pkgs; [
        # wayland env requirements
        qt5.qtwayland
        qt6.qtwayland

        # wayland adjacent
        sirula # launcher
        wayout # display on/off
        wl-clipboard # wl-{copy,paste}
        wtype # virtual keystroke insertion

        # misc utils
        # imv
        # oculante
        grim
        slurp
      ];
    };

    fonts = {
      fonts = with pkgs; [
        fira-code
        fira-code-symbols
        open-sans
        jetbrains-mono
        siji
        font-awesome
        noto-fonts-cjk-sans
        noto-fonts-cjk-serif
      ];
    };

    # services.greetd = {
    #   enable = true;
    #   settings = {
    #
    #     default_session = {
    #       command = "${pkgs.greetd.greetd}/bin/agreety --cmd sway";
    #     };
    #
    #   };
    # };
    security.pam.services.swaylock = {
      text = ''
        auth include login
      '';
    };

    home-manager.users.emiller.wayland.windowManager.sway = {
      extraSessionCommands = ''
        export WLR_NO_HARDWARE_CURSORS=1
        export NIXOS_OZONE_WL=1
      '';
    };
        environment.sessionVariables = {
      WLR_DRM_NO_ATOMIC = "1";
      LIBVA_DRIVER_NAME = "nvidia";
      MOZ_DISABLE_RDD_SANDBOX = "1";
      EGL_PLATFORM = "wayland";
    };

    services.xserver.screenSection = ''
      Option         "metamodes" "nvidia-auto-select +0+0 {ForceFullCompositionPipeline=On}"
      Option         "AllowIndirectGLXProtocol" "off"
      Option         "TripleBuffer" "on"
    '';
    hardware.nvidia.powerManagement.enable = false;
  };
}