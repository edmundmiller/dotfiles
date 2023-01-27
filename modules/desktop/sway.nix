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
      wayland.windowManager.sway.config.modifier = "Mod4";
      wayland.windowManager.sway.extraConfig = ''
        input "type:keyboard" {
            xkb_options caps:escape
        }
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
          timeout = 10;
          command = "${pkgs.swaylock}/bin/swaylock -fF";
        }];
      };

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

    services.xserver.displayManager.gdm.enable = true;
  };
}
