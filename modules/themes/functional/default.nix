# modules/themes/functional/default.nix --- For functional genomics/programming
{
  config,
  lib,
  pkgs,
  isDarwin,
  ...
}:
with lib;
with lib.my;
let
  cfg = config.modules.theme;
in
{
  config = mkIf (cfg.active == "functional") (mkMerge [
    # Desktop-agnostic configuration
    {
      modules = {
        theme = {
          wallpaper = mkDefault ./config/wallpaper.png;
          gtk = {
            theme = "Dracula";
            iconTheme = "Paper";
            cursorTheme = "Paper";
          };
          fonts = {
            sans.name = "Fira Sans";
            mono.name = "Fira Code";
          };
          colors = {
            black = "#1E2029";
            red = "#ffb86c";
            green = "#50fa7b";
            yellow = "#f0c674";
            blue = "#61bfff";
            magenta = "#bd93f9";
            cyan = "#8be9fd";
            silver = "#e2e2dc";
            grey = "#5B6268";
            brightred = "#de935f";
            brightgreen = "#0189cc";
            brightyellow = "#f9a03f";
            brightblue = "#8be9fd";
            brightmagenta = "#ff79c6";
            brightcyan = "#0189cc";
            white = "#f8f8f2";

            types.fg = "#bbc2cf";
            types.panelbg = "#21242b";
            types.border = "#1a1c25";
          };
        };

        shell.zsh.rcFiles = [ ./config/zsh/prompt.zsh ];
        shell.tmux.rcFiles = [ ./config/tmux.conf ];
      };
    }

    # Desktop (X11) theming (NixOS only)
    (optionalAttrs (!isDarwin) (
      mkIf (config.services.xserver.enable or false) {
        user.packages = with pkgs; [
          unstable.dracula-theme
          paper-icon-theme # for rofi
        ];
        fonts = {
          packages = with pkgs; [
            fira-code
            fira-code-symbols
            open-sans
            jetbrains-mono
            ia-writer-duospace
            siji
            font-awesome
          ];
        };

        # Compositor
        services.picom = {
          fade = true;
          fadeDelta = 1;
          fadeSteps = [
            1.0e-2
            1.2e-2
          ];
          shadow = true;
          shadowOffsets = [
            (-10)
            (-10)
          ];
          shadowOpacity = 0.22;
          # activeOpacity = "1.00";
          # inactiveOpacity = "0.92";
          settings = {
            shadow-radius = 12;
            # blur-background = true;
            # blur-background-frame = true;
            # blur-background-fixed = true;
            blur-kern = "7x7box";
            blur-strength = 320;
          };
        };

        # Login screen theme
        services.xserver.displayManager.lightdm.greeters.mini.extraConfig = ''
          text-color = "${cfg.colors.magenta}"
          password-background-color = "${cfg.colors.black}"
          window-color = "${cfg.colors.types.border}"
          border-color = "${cfg.colors.types.border}"
        '';

        # Other dotfiles (NixOS-specific desktop configurations)
        home.configFile = mkMerge [
          # Basic theme file (works on all platforms)
          {
            "xtheme/90-theme".source = ./config/Xresources;
          }
          # Desktop-specific configurations (NixOS only)
          (mkIf (!isDarwin) (
            with config.modules;
            mkMerge [
              (mkIf desktop.bspwm.enable {
                "bspwm/rc.d/00-theme".source = ./config/bspwmrc;
                "bspwm/rc.d/95-polybar".source = ./config/polybar/run.sh;
              })
              (mkIf desktop.apps.rofi.enable {
                "rofi/theme" = {
                  source = ./config/rofi;
                  recursive = true;
                };
              })
              (mkIf desktop.bspwm.enable {
                "polybar" = {
                  source = ./config/polybar;
                  recursive = true;
                };
                "dunst/dunstrc".text = import ./config/dunstrc cfg;
                "Dracula-purple-solid-kvantum" = {
                  recursive = true;
                  source = "${pkgs.unstable.dracula-theme}/share/themes/Dracula/kde/kvantum/Dracula-purple-solid";
                  target = "Kvantum/Dracula-purple-solid";
                };
                "kvantum.kvconfig" = {
                  text = "theme=Dracula-purple-solid";
                  target = "Kvantum/kvantum.kvconfig";
                };
              })
              (mkIf desktop.media.graphics.vector.enable {
                "inkscape/templates/default.svg".source = ./config/inkscape/default-template.svg;
              })
              (mkIf desktop.browsers.qutebrowser.enable {
                "qutebrowser/extra/theme.py".source = ./config/qutebrowser/theme.py;
              })
            ]
          ))
        ];
      }
    ))
  ]);
}
