{
  config,
  lib,
  pkgs,
  isDarwin,
  ...
}:
with lib;
with lib.my;
let
  cfg = config.modules.services.homebox;
  homeboxPackage = pkgs.homebox.overrideAttrs (
    old:
    let
      version = "0.26.2";
      src = pkgs.fetchFromGitHub {
        owner = "sysadminsmedia";
        repo = "homebox";
        tag = "v${version}";
        hash = "sha256-JUhRpUWbydy28Xw7j6oCKJLBmaOxcruWAdkqm+hvouY=";
      };
    in
    {
      inherit version src;
      vendorHash = "sha256-peQaPSbxGn8MnbZPqCi5ptW+dMh9l4W1hB6HqBLTqh4=";
      pnpmDeps = pkgs.fetchPnpmDeps {
        inherit (old) pname;
        inherit version;
        src = "${src}/frontend";
        pnpm = pkgs.pnpm_10;
        fetcherVersion = 3;
        hash = "sha256-oHS2uMWyuqpiK7yWznmZ2mgxPJpWsyOZL2wz6zBu0cc=";
      };
      ldflags = [
        "-s"
        "-w"
        "-extldflags=-static"
        "-X main.version=v${version}"
        "-X main.commit=v${version}"
      ];
    }
  );
in
{
  options.modules.services.homebox = {
    enable = mkBoolOpt false;
    allowRegistration = mkBoolOpt false;
    environmentFile = mkOpt (types.nullOr types.path) null;

    tailscaleService = {
      enable = mkBoolOpt false;
      serviceName = mkOpt types.str "homebox";
    };
  };

  config = mkIf cfg.enable (
    optionalAttrs (!isDarwin) {
      assertions = [
        {
          assertion = cfg.environmentFile != null;
          message = "modules.services.homebox.environmentFile must provide HBOX_AUTH_API_KEY_PEPPER";
        }
      ];

      services.homebox = {
        enable = true;
        package = homeboxPackage;
        settings = {
          HBOX_WEB_HOST = "127.0.0.1";
          HBOX_WEB_PORT = "7745";
          HBOX_OPTIONS_ALLOW_REGISTRATION = boolToString cfg.allowRegistration;
          HBOX_OPTIONS_TRUST_PROXY = "true";
          HBOX_OPTIONS_HOSTNAME = "https://homebox.cinnamon-rooster.ts.net";
          HBOX_OPTIONS_ALLOW_ANALYTICS = "false";
        };
      };

      age.secrets.homebox-env = {
        owner = "homebox";
        group = "homebox";
      };

      systemd.services = {
        homebox.serviceConfig.EnvironmentFile = cfg.environmentFile;

        homebox-tailscale-serve = mkIf cfg.tailscaleService.enable {
          description = "Tailscale Service proxy for Homebox";
          wantedBy = [ "multi-user.target" ];
          after = [
            "homebox.service"
            "tailscaled.service"
          ];

          serviceConfig = {
            Type = "oneshot";
            RemainAfterExit = true;
            ExecStart = "${pkgs.bash}/bin/bash -c '${pkgs.util-linux}/bin/flock /run/tailscale-serve.lock ${pkgs.bash}/bin/bash -c \"for i in \\$(seq 1 15); do ${pkgs.tailscale}/bin/tailscale serve --bg --service=svc:${cfg.tailscaleService.serviceName} --https=443 http://127.0.0.1:7745 && exit 0; sleep 1; done; exit 1\"'";
            ExecStop = "${pkgs.bash}/bin/bash -c '${pkgs.tailscale}/bin/tailscale serve clear svc:${cfg.tailscaleService.serviceName} || true'";
          };
        };
      };
    }
  );
}
