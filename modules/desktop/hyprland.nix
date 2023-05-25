{ options, config, lib, pkgs, ... }:

with lib;
with lib.my;
let cfg = config.modules.desktop.hyprland;
in {
  options.modules.desktop.hyprland = { enable = mkBoolOpt false; };

  config = mkIf cfg.enable {
    programs.hyprland.enable = true;
    programs.hyprland.xwayland.hidpi = true;

    fonts = {
      fonts = with pkgs; [
        fira-code
        fira-code-symbols
        open-sans
        jetbrains-mono
        ia-writer-duospace
        siji
        font-awesome
      ];
    };

    environment.sessionVariables.NIXOS_OZONE_WL = "1";

    environment.systemPackages = with pkgs; [
      dunst
      libnotify
      (waybar.override {
        wireplumberSupport = true;
        nlSupport = true;
      })
      grim
      slurp
      wf-recorder
    ];

    systemd.user.services."dunst" = {
      enable = true;
      description = "";
      wantedBy = [ "default.target" ];
      serviceConfig.Restart = "always";
      serviceConfig.RestartSec = 2;
      serviceConfig.ExecStart = "${pkgs.dunst}/bin/dunst";
    };

    services.greetd = {
      enable = true;

      settings = {
        default_session.command =
          "${pkgs.greetd.tuigreet}/bin/tuigreet --time --cmd 'Hyprland'";

        initial_session = {
          command = "Hyprland";
          user = "emiller";
        };
      };
    };
  };
}
