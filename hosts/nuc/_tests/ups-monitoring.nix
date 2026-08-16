{ nixosConfig, pkgs }:
let
  cfg = nixosConfig.config;
  ups = cfg.power.ups;
  cyberpower = ups.ups.cyberpower or { };
  monitor = ups.upsmon.monitor.cyberpower or { };
  listeners = map (listener: listener.address) ups.upsd.listen;
  assertions = [
    {
      test = ups.enable;
      msg = "NUC must enable NUT for graceful UPS-aware shutdown.";
    }
    {
      test = ups.mode == "standalone";
      msg = "NUC must run the USB driver, NUT server, and monitor locally.";
    }
    {
      test = !ups.openFirewall && listeners == [ "127.0.0.1" ];
      msg = "NUT telemetry must remain loopback-only with no firewall opening.";
    }
    {
      test = (cyberpower.driver or null) == "usbhid-ups" && (cyberpower.port or null) == "auto";
      msg = "CyberPower S175UC must use NUT's usbhid-ups driver.";
    }
    {
      test =
        builtins.elem "pollonly" (cyberpower.directives or [ ])
        && builtins.elem "maxretry = 5" (cyberpower.directives or [ ]);
      msg = "CyberPower S175UC must avoid broken interrupt transfers and retry USB startup.";
    }
    {
      test = (monitor.system or null) == "cyberpower@localhost" && (monitor.type or null) == "primary";
      msg = "The local NUT primary monitor must own graceful LOWBATT shutdown.";
    }
    {
      test = builtins.elem "nut" cfg.services.home-assistant.extraComponents;
      msg = "Home Assistant must include the NUT integration for read-only telemetry.";
    }
    {
      test = builtins.elem "systemd-udev-settle.service" cfg.systemd.services.upsdrv.after;
      msg = "The UPS driver must wait for USB udev events before starting.";
    }
  ];
  failures = builtins.filter (assertion: !assertion.test) assertions;
in
pkgs.runCommand "nuc-ups-monitoring" { } ''
  if [ ${toString (builtins.length failures)} -ne 0 ]; then
    cat >&2 <<'EOF'
  NUC UPS monitoring assertions failed:
  ${builtins.concatStringsSep "\n" (map (failure: "- ${failure.msg}") failures)}
  EOF
    exit 1
  fi

  touch "$out"
''
