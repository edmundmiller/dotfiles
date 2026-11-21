{ nixosConfig, pkgs }:
let
  cfg = nixosConfig.config;
  flags = cfg.services.tailscale.extraSetFlags;
  count = flag: builtins.length (builtins.filter (candidate: candidate == flag) flags);
  assertions = [
    {
      test = count "--ssh" == 1;
      msg = "NUC must advertise Tailscale SSH exactly once.";
    }
    {
      test = count "--advertise-routes=192.168.1.0/24" == 1;
      msg = "NUC must preserve its LAN subnet advertisement.";
    }
    {
      test = count "--operator=emiller" == 1;
      msg = "NUC must preserve emiller as the Tailscale operator.";
    }
    {
      test =
        cfg.virtualisation.oci-containers.containers.speedtest-tracker.environment.APP_URL
        == "https://speedtest-tracker.cinnamon-rooster.ts.net";
      msg = "Speedtest Tracker must generate links for its HTTPS service hostname.";
    }
  ]
  ++
    map
      (
        route:
        let
          serve = cfg.systemd.services."${route.name}-tailscale-serve".serviceConfig;
        in
        {
          test =
            pkgs.lib.hasInfix "--service=svc:${route.name} --https=443 http://127.0.0.1:${route.port}" serve.ExecStart
            &&
              cfg.modules.services.${route.name}.registry.homepage.href
              == "https://${route.name}.cinnamon-rooster.ts.net";
          msg = "${route.name} must expose its correct backend through its own HTTPS service hostname.";
        }
      )
      [
        {
          name = "radarr";
          port = "7878";
        }
        {
          name = "sonarr";
          port = "8989";
        }
        {
          name = "prowlarr";
          port = "9696";
        }
        {
          name = "lubelogger";
          port = "5000";
        }
        {
          name = "speedtest-tracker";
          port = "8765";
        }
      ];
  failures = builtins.filter (assertion: !assertion.test) assertions;
in
pkgs.runCommand "nuc-tailscale-ssh" { } ''
  if [ ${toString (builtins.length failures)} -ne 0 ]; then
    cat >&2 <<'EOF'
  NUC Tailscale SSH assertions failed:
  ${builtins.concatStringsSep "\n" (map (failure: "- ${failure.msg}") failures)}
  EOF
    exit 1
  fi

  touch "$out"
''
