{ config, pkgs, ... }: {

  environment.systemPackages = with pkgs; [
    steamcontroller-udev-rules
    steam
    steam-run
  ];

  hardware.opengl.driSupport32Bit = true;
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
