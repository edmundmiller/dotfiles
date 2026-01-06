{
  options,
  config,
  lib,
  pkgs,
  ...
}:
with lib;
with lib.my;
let
  cfg = config.modules.desktop.gnome.dconf;
in
{
  options.modules.desktop.gnome.dconf = {
    enable = mkBoolOpt false;
  };

  config = mkIf cfg.enable {
    home-manager.users.${config.user.name} = {
      dconf.settings = {
        "org/gnome/shell" = {
          favorite-apps = [
            "floorp.desktop"
            "emacs.desktop"
            "com.mitchellh.ghostty.desktop"
            "1password.desktop"
          ];
        };
        "org/gnome/desktop/interface" = {
          enable-hot-corners = false;
        };

        # Workspaces
        "org/gnome/mutter" = {
          dynamic-workspaces = false;
        };
        "org/gnome/desktop/wm/preferences" = {
          button-layout = "appmenu:minimize,maximize,close";
          num-workspaces = 5;
          workspace-names = [
            "Web"
            "Editor"
            "Terminal"
            "Chat"
            "Scratch"
          ];
        };
        "org/gnome/shell/app-switcher" = {
          current-workspace-only = true;
        };

        "org/gnome/shell" = {
          disable-user-extensions = false;

          # `gnome-extensions list` for a list
          enabled-extensions = [
            "user-theme@gnome-shell-extensions.gcampax.github.com"
            "trayIconsReloaded@selfmade.pl"
            "Vitals@CoreCoding.com"
            "dash-to-panel@jderose9.github.com"
            "sound-output-device-chooser@kgshank.net"
            "space-bar@luchrioh"
            "gsconnect@andyholmes.github.io"
            # TODO https://extensions.gnome.org/extension/4548/tactile/

            # TODO Enable only on meshify
            # "ionutbortis/gnome-bedtime-mode"
            # gnome-shell
            "user-theme@gnome-shell-extensions.gcampax.github.com"
          ];

          # FIXME Configure extensions
          # "org/gnome/shell/extensions/user-theme" = {
          #   name = "palenight";
          # };
          #
          # "org/gnome/shell/extensions/space-bar/shortcuts" = {
          #   enable-move-to-workspace-shortcuts = true;
          # };
          # "org/gnome/shell/extensions/dash-to-panel" = {
          #   trans-use-custom-bg = true;
          #   trans-use-custom-opacity = true;
          #   intellihide-use-pressure = true;
          #   # FIXME
          #   # trans-panel-opacity = "0.4";
          #   # panel-sizes = "{\"0\":24}";
          #   # intellihide-behaviour = "ALL_WINDOWS";
          #   # FIXME I'd like to have this but it breaks workspace switching
          #   isolate-workspaces = false;
          #   hot-keys = true;
          # };
        };
      };
    };

    user.packages = with pkgs; [
      # ...
      # TODO Add Tailscale
      gnomeExtensions.tray-icons-reloaded
      gnomeExtensions.vitals
      gnomeExtensions.dash-to-panel
      gnomeExtensions.sound-output-device-chooser
      gnomeExtensions.space-bar
      gnomeExtensions.gsconnect
      # gnome-shell
      gnomeExtensions.user-themes
      palenight-theme
    ];
  };
}
