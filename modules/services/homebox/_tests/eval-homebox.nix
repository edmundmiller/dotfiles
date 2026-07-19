# Pure Nix eval test: assert Homebox stays private, recoverable, and registration-locked.
{ nixosConfig, pkgs }:
let
  inherit (builtins)
    concatStringsSep
    elem
    filter
    head
    isList
    length
    ;
  inherit (pkgs.lib.strings) hasInfix;

  cfg = nixosConfig.config;
  homebox = cfg.services.homebox or { };
  settings = homebox.settings or { };
  homeboxService = cfg.systemd.services.homebox or { };
  environmentFile = homeboxService.serviceConfig.EnvironmentFile or null;
  serveService = cfg.systemd.services.homebox-tailscale-serve or { };
  serveExecStart = serveService.serviceConfig.ExecStart or "";
  backup = cfg.services.restic.backups.homebox-state or { };
  homepageServices = cfg.services.homepage-dashboard.services or [ ];
  homeSection = head (filter (section: section ? Home) homepageServices);
  homeboxEntries = filter (entry: entry ? Homebox) homeSection.Home;
  homepageHomebox = if homeboxEntries == [ ] then { } else (head homeboxEntries).Homebox;
  widget = homepageHomebox.widget or { };

  hasEnvironmentFile =
    environmentFile == "/run/agenix/homebox-env"
    || (isList environmentFile && elem "/run/agenix/homebox-env" environmentFile);

  assertions = [
    {
      test = homebox.enable or false;
      msg = "Homebox must be enabled on the NUC";
    }
    {
      test = (homebox.package.version or "") == "0.26.2";
      msg = "Homebox must use pinned package version 0.26.2";
    }
    {
      test = (settings.HBOX_WEB_HOST or "") == "127.0.0.1";
      msg = "Homebox must listen on loopback only";
    }
    {
      test = (settings.HBOX_WEB_PORT or "") == "7745";
      msg = "Homebox must listen on port 7745";
    }
    {
      test = (settings.HBOX_OPTIONS_ALLOW_REGISTRATION or "") == "false";
      msg = "Homebox registration must be disabled after bootstrap";
    }
    {
      test =
        widget == {
          type = "homebox";
          url = "http://127.0.0.1:7745";
          username = "{{HOMEPAGE_VAR_HOMEBOX_USERNAME}}";
          password = "{{HOMEPAGE_VAR_HOMEBOX_PASSWORD}}";
          fields = [
            "items"
            "locations"
            "totalValue"
          ];
        };
      msg = "Homepage must render the authenticated Homebox widget";
    }
    {
      test = hasEnvironmentFile;
      msg = "Homebox must load /run/agenix/homebox-env";
    }
    {
      test = hasInfix "--service=svc:homebox" serveExecStart;
      msg = "Homebox Tailscale Serve must advertise svc:homebox";
    }
    {
      test = hasInfix "http://127.0.0.1:7745" serveExecStart;
      msg = "Homebox Tailscale Serve must proxy to loopback port 7745";
    }
    {
      test = elem "/var/lib/homebox" (backup.paths or [ ]);
      msg = "Homebox backup must include /var/lib/homebox";
    }
    {
      test =
        elem "--tag" (backup.extraBackupArgs or [ ])
        && elem "homebox-state" (backup.extraBackupArgs or [ ]);
      msg = "Homebox backup must use the homebox-state tag";
    }
    {
      test = (backup.pruneOpts or null) == [ ];
      msg = "Homebox backup must not prune while Homebox is stopped";
    }
  ];

  failures = filter (assertion: !assertion.test) assertions;
  resultText =
    if failures == [ ] then
      "All ${toString (length assertions)} Homebox assertions passed."
    else
      concatStringsSep "\n" (
        [ "${toString (length failures)}/${toString (length assertions)} Homebox assertions failed:" ]
        ++ map (assertion: "  FAIL: ${assertion.msg}") failures
      );
in
pkgs.runCommand "homebox-assertions"
  {
    passthru = { inherit assertions failures; };
  }
  ''
    ${
      if failures == [ ] then
        ''
          echo "${resultText}"
          mkdir -p $out
          echo "${resultText}" > $out/result
        ''
      else
        ''
          echo "${resultText}" >&2
          exit 1
        ''
    }
  ''
