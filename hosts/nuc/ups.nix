{
  config,
  lib,
  ...
}:
{
  # NUT is the single owner of the UPS USB connection and host shutdown.
  # Home Assistant only reads upsd telemetry over loopback.
  power.ups = {
    enable = true;
    mode = "standalone";
    openFirewall = false;

    ups.cyberpower = {
      driver = "usbhid-ups";
      port = "auto";
      description = "CyberPower S175UC";
      directives = [
        "vendorid = 0764"
        "productid = 0501"
        "pollonly"
        "maxretry = 5"
        "retrydelay = 3"
        "offdelay = 60"
        "ondelay = 120"
      ];
    };

    upsd.listen = [
      {
        address = "127.0.0.1";
        port = 3493;
      }
    ];

    users.nut-monitor = {
      passwordFile = config.age.secrets.nut-monitor-password.path;
      upsmon = "primary";
    };

    upsmon.monitor.cyberpower = {
      system = "cyberpower@localhost";
      powerValue = 1;
      user = "nut-monitor";
      type = "primary";
    };
  };

  age.secrets.nut-monitor-password = {
    owner = "root";
    group = "root";
    mode = "0400";
  };

  services.home-assistant.extraComponents = [ "nut" ];

  # Start the USB driver before its consumers. The upstream module's units
  # otherwise converge eventually through retries but have reverse ordering.
  systemd.services.upsdrv = {
    after = lib.mkForce [ "systemd-udev-settle.service" ];
    before = [ "upsd.service" ];
    requiredBy = [ "upsd.service" ];
    wants = [ "systemd-udev-settle.service" ];
  };
  systemd.services.upsd = {
    after = lib.mkForce [
      "network.target"
      "upsdrv.service"
    ];
    before = [ "upsmon.service" ];
    requiredBy = [ "upsmon.service" ];
  };
  systemd.services.upsmon.after = lib.mkForce [
    "network.target"
    "upsd.service"
  ];
}
