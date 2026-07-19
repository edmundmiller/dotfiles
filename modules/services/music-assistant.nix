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
  cfg = config.modules.services.music-assistant;
in
{
  options.modules.services.music-assistant = {
    enable = mkBoolOpt false;
    port = mkOption {
      type = types.port;
      default = 8095;
      readOnly = true;
      description = "Music Assistant's fixed server port.";
    };

    tailscaleService = {
      enable = mkBoolOpt false;
      serviceName = mkOpt types.str "music-assistant";
    };
  };

  config = mkIf cfg.enable (
    optionalAttrs (!isDarwin) {
      systemd.tmpfiles.rules = [
        "d /var/lib/music-assistant 0750 root root -"
      ];

      virtualisation.oci-containers.containers.music-assistant = {
        autoStart = true;
        image = "ghcr.io/music-assistant/server:2.9.9";
        volumes = [ "/var/lib/music-assistant:/data" ];
        extraOptions = [ "--network=host" ];
      };

      networking.firewall.interfaces.tailscale0.allowedTCPPorts = [ cfg.port ];

      systemd.services.music-assistant-tailscale-serve = mkIf cfg.tailscaleService.enable {
        description = "Tailscale Service proxy for Music Assistant";
        wantedBy = [ "multi-user.target" ];
        after = [
          "${config.virtualisation.oci-containers.backend}-music-assistant.service"
          "tailscaled.service"
        ];

        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          ExecStart = "${pkgs.bash}/bin/bash -c '${pkgs.util-linux}/bin/flock /run/tailscale-serve.lock ${pkgs.bash}/bin/bash -c \"for i in \\$(seq 1 15); do ${pkgs.tailscale}/bin/tailscale serve --bg --service=svc:${cfg.tailscaleService.serviceName} --https=443 http://localhost:${toString cfg.port} && exit 0; sleep 1; done; exit 1\"'";
          ExecStop = "${pkgs.bash}/bin/bash -c '${pkgs.tailscale}/bin/tailscale serve clear svc:${cfg.tailscaleService.serviceName} || true'";
        };
      };

    }
  );
}
