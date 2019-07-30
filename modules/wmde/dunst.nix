{ config, lib, pkgs, ... }:

{
  environment.systemPackages = with pkgs; [ dunst ];

  home-manager.users.emiller = {
    services.dunst = {
      enable = true;
      iconTheme = {
        package = pkgs.paper-icon-theme;
        name = "Paper-Mono-Dark";
      };
      settings = {
        global = {
          alignment = [ "left" ];
          markup = [ "full" ];
          bounce_freq = 0;
          browser = [ "/usr/bin/firefox -new-tab" ];
          dmenu = [ "/usr/bin/rofi -dmenu -p dunst:" ];
          follow = [ "none" ];
          font = "Iosevka 12";
          format = "%s\\n%b";
          # geometry [{width}]x{height}][+/-{x}+/-{y}]
          geometry = "365x15-21+21";
          history_length = 20;
          horizontal_padding = 16;
          idle_threshold = 120;
          ignore_newline = false;
          indicate_hidden = true;
          line_height = 0;
          monitor = 0;
          padding = 12;
          separator_color = "#18191b";
          separator_height = 2;
          show_age_threshold = 60;
          show_indicators = true;
          shrink = false;
          sort = true;
          startup_notification = [ "false" ];
          sticky_history = true;
          transparency = 1;
          word_wrap = true;
          max_icon_size = 64;
          # Align icons left/right/off
          icon_position = [ "right" ];
          frame_width = 0;
          frame_color = "#131416";
        };

        shortcuts = { context = [ "ctrl+shift+period" ]; };

        urgency_low = {
          # IMPORTANT: colors have to be defined in quotation marks.
          # Otherwise the "#" and following would be interpreted as a comment.
          background = "#0a0b0c";
          foreground = "#b5bd68";
          timeout = 8;
        };

        urgency_normal = {
          background = "#b5bd68";
          foreground = "#131416";
          timeout = 14;
        };
        urgency_critical = {
          background = "#cc6666";
          foreground = "#131416";
          timeout = 0;
        };
      };
    };
  };
  # https://gist.github.com/joedicastro/a19a9dfd21470783240c739657747f5d
  # systemd.user.services."dunst" = {
  #   enable = true;
  #   description = "";
  #   wantedBy = [ "default.target" ];
  #   serviceConfig.Restart = "always";
  #   serviceConfig.RestartSec = 2;
  #   serviceConfig.ExecStart = "${pkgs.dunst}/bin/dunst";
  # };
}
