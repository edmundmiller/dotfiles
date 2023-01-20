{ options, config, lib, pkgs, ... }:

with lib;
with lib.my;
let cfg = config.modules.desktop.sway;
in {
  options.modules.desktop.sway = { enable = mkBoolOpt false; };

  config = mkIf cfg.enable {
    home-manager.users.emiller = {
      wayland.windowManager.sway.enable = true;
      services.swayidle.enable = true;
      programs.foot.enable = true;
      wayland.windowManager.sway.config.modifier = "Mod4";
      wayland.windowManager.sway.extraConfig = ''
        input "type:keyboard" {
            xkb_options caps:escape
        }
      '';
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
