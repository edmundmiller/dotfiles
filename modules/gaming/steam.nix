{ config, pkgs, ... }: {

  my.packages = with pkgs; [
    # Get steam to keep its garbage out of $HOME
    (writeScriptBin "steam" ''
      #!${stdenv.shell}
      HOME="$XDG_DATA_HOME/steamlib" exec ${steam}/bin/steam "$@"
    '')
    # for GOG and humblebundle games
    (writeScriptBin "steam-run" ''
      #!${stdenv.shell}
      HOME="$XDG_DATA_HOME/steamlib" exec ${steam-run-native}/bin/steam-run "$@"
    '')
    steamcontroller-udev-rules
    # xboxdrv # driver for 360 controller
  ];

  hardware.opengl.driSupport32Bit = true;
  hardware.opengl.extraPackages32 = with pkgs.pkgsi686Linux; [ libva ];
  hardware.opengl.extraPackages = with pkgs; [ libva ];
  hardware.pulseaudio.support32Bit = true;
  nixpkgs.config.packageOverrides = pkgs: {
    steamcontroller-udev-rules = pkgs.writeTextFile {
      name = "steamcontroller-udev-rules";
      text = ''
        # This rule is needed for basic functionality of the controller in
        # Steam and keyboard/mouse emulation
        SUBSYSTEM=="usb", ATTRS{idVendor}=="28de", MODE="0666"

        # This rule is necessary for gamepad emulation; make sure you
        # replace 'pgriffais' with the username of the user that runs Steam
        KERNEL=="uinput", MODE="0660", GROUP="wheel", OPTIONS+="static_node=uinput"
        # systemd option not yet tested
        #KERNEL=="uinput", SUBSYSTEM=="misc", TAG+="uaccess", TAG+="udev-acl"
        # Valve HID devices over USB hidraw
        KERNEL=="hidraw*", ATTRS{idVendor}=="28de", MODE="0666"
        # Valve HID devices over bluetooth hidraw
        KERNEL=="hidraw*", KERNELS=="*28DE:*", MODE="0666"
      '';
      destination = "/etc/udev/rules.d/99-steamcontroller.rules";
    };
  };

  services.udev.packages = [ pkgs.steamcontroller-udev-rules ];
}
