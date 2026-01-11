# OpenPortal - Mobile-first web UI for OpenCode
# Access via Tailscale IP at http://[tailscale-ip]:3000
{ options, config, lib, pkgs, isDarwin, ... }:

with lib;
with lib.my;
let
  cfg = config.modules.services.openportal;
in {
  options.modules.services.openportal = {
    enable = mkBoolOpt false;
    projectDir = mkOpt types.str "${config.user.home}/src";
    openCodeImage = mkOpt types.str "ghcr.io/sst/opencode:1.0.162";
    portalImage = mkOpt types.str "ghcr.io/hosenur/portal:latest";
    openCodePort = mkOpt types.port 4000;
    portalPort = mkOpt types.port 3000;
  };

  # NixOS-only service (uses podman/systemd)
  config = optionalAttrs (!isDarwin) (mkIf cfg.enable {
    # Ensure podman is available
    virtualisation.podman.enable = true;
    virtualisation.oci-containers.backend = "podman";

    # Create project directory if it doesn't exist
    systemd.tmpfiles.rules = [
      "d ${cfg.projectDir} 0755 ${config.user.name} users -"
    ];

    # OpenCode server container
    virtualisation.oci-containers.containers.portal-opencode = {
      autoStart = true;
      image = cfg.openCodeImage;
      volumes = [ "${cfg.projectDir}:/app" ];
      extraOptions = [ "--network=host" ];
      # Detect Tailscale IP at runtime and bind to it
      entrypoint = "/bin/sh";
      cmd = [
        "-c"
        ''TS_IP=$(cat /proc/net/fib_trie | grep -oP '100\.\d+\.\d+\.\d+' | head -1); exec opencode serve --hostname $TS_IP --port ${toString cfg.openCodePort}''
      ];
    };

    # Portal UI container - needs wrapper script for dynamic Tailscale IP
    systemd.services.podman-portal-ui = {
      description = "OpenPortal Web UI";
      after = [ "network-online.target" "podman-portal-opencode.service" ];
      wants = [ "network-online.target" ];
      wantedBy = [ "multi-user.target" ];

      serviceConfig = {
        Type = "simple";
        Restart = "always";
        RestartSec = "10s";
        ExecStartPre = "${pkgs.coreutils}/bin/sleep 5";
      };

      script = ''
        TS_IP=$(${pkgs.tailscale}/bin/tailscale ip -4)
        ${pkgs.podman}/bin/podman run --rm \
          --name portal-ui \
          --network=host \
          -e OPENCODE_SERVER_URL="http://$TS_IP:${toString cfg.openCodePort}" \
          ${cfg.portalImage}
      '';

      preStop = ''
        ${pkgs.podman}/bin/podman stop portal-ui || true
      '';
    };

    # Open firewall ports (Tailscale traffic)
    networking.firewall.allowedTCPPorts = [ cfg.openCodePort cfg.portalPort ];
  });
}
