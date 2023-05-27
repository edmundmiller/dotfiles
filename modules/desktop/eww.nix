{
  config,
  lib,
  pkgs,
  ...
}:
with lib;
with lib.my; let
  dependencies = with pkgs; [
    # config.wayland.windowManager.hyprland.package
    # cfg.package
    # bash
    # blueberry
    # bluez
    # brillo
    # coreutils
    # dbus
    # findutils
    # gawk
    # gnome.gnome-control-center
    # gnused
    # imagemagick
    # jaq
    # jc
    # libnotify
    # networkmanager
    # pavucontrol
    # playerctl
    # procps
    # pulseaudio
    ripgrep
    # socat
    # udev
    # upower
    # util-linux
    # wget
    # wireplumber
    # wlogout
  ];
in {
  systemd.user.services.eww = {
    enable = true;
    description = "Eww Daemon";
    partOf = ["graphical-session.target"];
    serviceConfig = {
      Environment = "PATH=/run/wrappers/bin:${lib.makeBinPath dependencies}";
      ExecStart = "${pkgs.eww-wayland}/bin/eww daemon --no-daemonize";
      Restart = "on-failure";
    };
    wantedBy = ["graphical-session.target"];
  };

  home.configFile = {
    "eww" = {
      source = "${configDir}/eww";
      recursive = true;
    };
  };
}
