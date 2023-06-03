{
  options,
  config,
  lib,
  pkgs,
  inputs,
  ...
}:
with lib;
with lib.my; let
  cfg = config.modules.desktop.hyprland;
in {
  imports = [./eww.nix inputs.hyprland.nixosModules.default];
  options.modules.desktop.hyprland = {enable = mkBoolOpt false;};

  config = mkIf cfg.enable (mkMerge [
    # Basics
    {
      programs.hyprland = {
        enable = true;
        xwayland.enable = true;
        xwayland.hidpi = true;
      };

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

      environment.systemPackages = with pkgs;
      with inputs.hyprland-contrib.packages.${pkgs.system}; [
        dunst
        libnotify
        (waybar.override {
          wireplumberSupport = true;
          nlSupport = true;
        })
        wl-clipboard
        grimblast
        wf-recorder
        wlsunset
        scratchpad
        wofi
        hyprpicker
      ];

      systemd.user.services."dunst" = {
        enable = true;
        description = "";
        wantedBy = ["default.target"];
        serviceConfig.Restart = "always";
        serviceConfig.RestartSec = 2;
        serviceConfig.ExecStart = "${pkgs.dunst}/bin/dunst";
      };

      # systemd.user.services.swayidle.Install.WantedBy =
      #   lib.mkForce [ "hyprland-session.target" ];

      services.greetd = {
        enable = true;
        settings = {
          default_session = {
            command = "${pkgs.greetd.tuigreet}/bin/tuigreet --time --cmd 'Hyprland' --remember --asterisks --user-menu";
            user = "emiller";
          };
        };
      };

      security.pam.services.swaylock = {
        text = ''
          auth include login
        '';
      };
    }

    # Nvidia
    (mkIf config.modules.hardware.nvidia.enable {
      programs.hyprland.nvidiaPatches = true;
      environment.sessionVariables.WLR_NO_HARDWARE_CURSORS = "1";
    })
  ]);
}
