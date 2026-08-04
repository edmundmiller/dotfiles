# Homepage Dashboard
# Tailscale: https://homepage.<tailnet>.ts.net
# Direct: http://<tailscale-ip>:8082
#
# Setup (one-time):
# 1. Tailscale admin → Services → Create service
# 2. Name: "homepage", endpoint: tcp:443, tag: tag:server
# 3. Deploy: hey nuc
# 4. Approve host in admin console
{
  config,
  lib,
  pkgs,
  ...
}:
with lib;
with lib.my;
let
  cfg = config.modules.services.homepage;
  homepagePort = 8082;
  tailnet = "cinnamon-rooster.ts.net";

  # Cards contributed by the services themselves via
  # `modules.services.<name>.registry.homepage`. Adding a dashboard card is a
  # one-line change in that service's own module, not an edit here.
  #
  # Groups stay literal where they mix registry cards with external entries
  # (Router, NextDNS, Tailscale, Grafana Cloud, Healthchecks) that have no
  # owning module to hang a registry off.
  #
  # Sub-services count too: `hass.homebridge` has its own `enable` and its own
  # registry, so it is gated on that flag rather than on its parent's.
  registryContributors =
    let
      isContributor = v: builtins.isAttrs v && v ? registry && v ? enable;
      children = svc: filter isContributor (attrValues (removeAttrs svc [ "registry" ]));
      collect = svc: [ svc ] ++ children svc;
    in
    concatMap collect (filter isContributor (attrValues config.modules.services));

  # A group's cards are the hard-coded ones plus the registry-contributed ones,
  # sorted together by `order` (then name) so registry cards land in the same
  # positions they occupied when they were hard-coded here. `order` is display
  # metadata and is stripped before rendering.
  mkGroup =
    group: literals:
    map
      (entry: {
        ${entry.name} = {
          inherit (entry) href description icon;
        }
        // optionalAttrs (entry.widget or null != null) { inherit (entry) widget; };
      })
      (
        sort (a: b: if a.order != b.order then a.order < b.order else a.name < b.name) (
          literals
          ++ concatMap (
            svc:
            let
              entry = svc.registry.homepage;
            in
            optional (svc.enable && entry != null && entry.group == group) entry
          ) registryContributors
        )
      );
in
{
  options.modules.services.homepage = {
    enable = mkBoolOpt false;
    tailscaleService = {
      enable = mkBoolOpt false;
      serviceName = mkOpt types.str "homepage";
    };
    # environmentFile should contain HOMEPAGE_VAR_* entries, e.g.:
    #   HOMEPAGE_VAR_HASS_TOKEN=...
    #   HOMEPAGE_VAR_HOMEBRIDGE_PASSWORD=...
    #   HOMEPAGE_VAR_JELLYFIN_API_KEY=...
    #   HOMEPAGE_VAR_NEXTDNS_PROFILE=...
    #   HOMEPAGE_VAR_NEXTDNS_API_KEY=...
    #   HOMEPAGE_VAR_LUBELOGGER_USERNAME=...
    #   HOMEPAGE_VAR_LUBELOGGER_PASSWORD=...
    #   HOMEPAGE_VAR_SPEEDTEST_API_KEY=...
    environmentFile = mkOpt (types.nullOr types.path) null;
    # Raw secret files (each containing just a value) to inject as env vars.
    # Reuse existing agenix secrets without duplicating them in environmentFile.
    # Each entry becomes <envVar>=<contents of path> at service start.
    #   environmentSecrets = [
    #     { envVar = "HOMEPAGE_VAR_FOO"; path = config.age.secrets.foo.path; }
    #   ];
    environmentSecrets = mkOpt (types.listOf (
      types.submodule {
        options = {
          envVar = mkOpt types.str "";
          path = mkOpt types.path (throw "environmentSecrets entry requires a path");
        };
      }
    )) [ ];
  };

  config = mkIf cfg.enable {
    services.homepage-dashboard = {
      enable = true;
      listenPort = homepagePort;
      openFirewall = true;

      allowedHosts = concatStringsSep "," (
        [
          "localhost:${toString homepagePort}"
          "nuc.${tailnet}:${toString homepagePort}"
        ]
        ++ optionals cfg.tailscaleService.enable [
          # Tailscale serve proxies HTTPS — Host header has no port
          "${cfg.tailscaleService.serviceName}.${tailnet}"
        ]
      );

      settings = {
        title = "Home Ops";
        favicon = "https://nixos.org/favicon.png";
        theme = "dark";
        color = "slate";
        headerStyle = "clean";
        hideVersion = true;
      };

      environmentFiles = lib.optional (cfg.environmentFile != null) cfg.environmentFile;

      widgets = [
        { logo = { }; }
        {
          resources = {
            cpu = true;
            memory = true;
            disk = "/";
          };
        }
        {
          datetime = {
            text_size = "xl";
            format = {
              timeStyle = "short";
              dateStyle = "short";
              hourCycle = "h23";
            };
          };
        }
        {
          search = {
            provider = "duckduckgo";
            target = "_blank";
          };
        }
      ];

      bookmarks = [
        {
          "Admin" = [
            {
              "Tools" = [
                {
                  href = "https://trmnl.com/dashboard";
                  description = "TRMNL dashboard";
                }
              ];
            }
          ];
        }
      ];

      services = [
        { "Media" = mkGroup "Media" [ ]; }
        { "Downloads" = mkGroup "Downloads" [ ]; }
        {
          "Home" = mkGroup "Home" [
            {
              name = "Mill Docs Agents";
              order = 50;
              href = "https://mill-docs-agents.${tailnet}";
              description = "Agent docs";
              icon = "mdi-file-document-outline";
            }
          ];
        }
        {
          "Network" = mkGroup "Network" [
            {
              name = "Router";
              order = 10;
              href = "http://192.168.1.254/cgi-bin/home.ha";
              description = "Router admin";
              icon = "mdi-router-wireless";
            }
            {
              name = "NextDNS";
              order = 20;
              href = "https://my.nextdns.io";
              description = "DNS filtering";
              icon = "nextdns.svg";
              widget = {
                type = "nextdns";
                profile = "{{HOMEPAGE_VAR_NEXTDNS_PROFILE}}";
                key = "{{HOMEPAGE_VAR_NEXTDNS_API_KEY}}";
              };
            }
            {
              name = "Tailscale";
              order = 30;
              href = "https://login.tailscale.com/admin";
              description = "VPN mesh admin";
              icon = "tailscale.svg";
            }
          ];
        }
        {
          "Monitoring" = mkGroup "Monitoring" [
            {
              name = "Gatus";
              order = 10;
              href = "https://gatus.${tailnet}";
              description = "Status page";
              icon = "gatus.svg";
              widget = {
                type = "gatus";
                url = "http://localhost:8084";
              };
            }
            {
              name = "Healthchecks";
              order = 20;
              href = "https://healthchecks.io";
              description = "Cron job monitoring";
              icon = "healthchecks.svg";
              widget = {
                type = "healthchecks";
                url = "https://healthchecks.io";
                key = "{{HOMEPAGE_VAR_HEALTHCHECKS_API_KEY}}";
              };
            }
            {
              name = "Grafana Cloud";
              order = 30;
              href = "https://fearlesslorry169.grafana.net/";
              description = "Metrics dashboards";
              icon = "grafana.svg";
            }
          ];
        }
      ];
    };

    # Inject raw agenix secrets as HOMEPAGE_VAR_* env vars.
    # Uses activationScript (runs as root, after agenix, before services) to generate
    # /run/homepage-secrets-env/secrets.env, then loads it via EnvironmentFile.
    # ExecStartPre can't be used: systemd loads EnvironmentFile before ExecStartPre runs,
    # and DynamicUser=true prevents ExecStartPre from reading agenix secrets.
    system.activationScripts.homepage-secrets = mkIf (cfg.environmentSecrets != [ ]) {
      deps = [ "agenix" ];
      text = ''
        mkdir -p /run/homepage-secrets-env
        : > /run/homepage-secrets-env/secrets.env
        chmod 600 /run/homepage-secrets-env/secrets.env
        ${concatMapStrings (
          { envVar, path }:
          ''
            printf '%s=%s\n' ${lib.escapeShellArg envVar} "$(cat ${lib.escapeShellArg (toString path)})" \
              >> /run/homepage-secrets-env/secrets.env
          ''
        ) cfg.environmentSecrets}
      '';
    };

    systemd.services.homepage-dashboard = mkIf (cfg.environmentSecrets != [ ]) {
      serviceConfig = {
        EnvironmentFile = mkForce (
          lib.optional (cfg.environmentFile != null) cfg.environmentFile
          ++ [ "/run/homepage-secrets-env/secrets.env" ]
        );
      };
    };

    # Tailscale serve — HTTPS at https://homepage.<tailnet>
    systemd.services.homepage-tailscale-serve = mkIf cfg.tailscaleService.enable {
      description = "Tailscale serve proxy for Homepage Dashboard";
      wantedBy = [ "multi-user.target" ];
      after = [
        "homepage-dashboard.service"
        "tailscaled.service"
      ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = "${pkgs.bash}/bin/bash -c '${pkgs.util-linux}/bin/flock /run/tailscale-serve.lock ${pkgs.bash}/bin/bash -c \"for i in \\$(seq 1 15); do ${pkgs.tailscale}/bin/tailscale serve --bg --service=svc:${cfg.tailscaleService.serviceName} --https=443 http://localhost:${toString homepagePort} && exit 0; sleep 1; done; exit 1\"'";
        ExecStop = "${pkgs.bash}/bin/bash -c '${pkgs.tailscale}/bin/tailscale serve clear svc:${cfg.tailscaleService.serviceName} || true'";
      };
    };

    environment.systemPackages = [ config.services.homepage-dashboard.package ];
  };
}
