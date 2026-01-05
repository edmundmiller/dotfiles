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
    projectDir = mkOpt (types.nullOr types.str) null;
    openCodeImage = mkOpt types.str "ghcr.io/sst/opencode:1.0.162";
    portalImage = mkOpt types.str "ghcr.io/hosenur/portal:latest";
    openCodePort = mkOpt types.port 4000;
    portalPort = mkOpt types.port 3000;
  };

  # NixOS-only service (uses podman/systemd)
  config = optionalAttrs (!isDarwin) (mkIf cfg.enable (let
    projectDir = if cfg.projectDir != null then cfg.projectDir else "${config.user.home}/src";
  in {
    # Ensure podman is available
    virtualisation.podman.enable = true;

    # Create project directory if it doesn't exist
    systemd.tmpfiles.rules = [
      "d ${projectDir} 0755 ${config.user.name} users -"
    ];

    # OpenCode server container - manual systemd service for dynamic Tailscale IP detection
    systemd.services.podman-portal-opencode = {
      description = "OpenCode Server";
      after = [ "network-online.target" "tailscaled.service" ];
      wants = [ "network-online.target" ];
      wantedBy = [ "multi-user.target" ];

      serviceConfig = {
        Type = "simple";
        Restart = "always";
        RestartSec = "10s";
      };

      script = ''
        TS_IP=$(${pkgs.tailscale}/bin/tailscale ip -4)
        ${pkgs.podman}/bin/podman run --rm \
          --name portal-opencode \
          --network=host \
          -v "${projectDir}:/app" \
          ${cfg.openCodeImage} \
          serve --hostname "$TS_IP" --port ${toString cfg.openCodePort}
      '';

      preStop = ''
        ${pkgs.podman}/bin/podman stop portal-opencode || true
      '';
    };

    # Portal UI container - wrapper script for dynamic Tailscale IP
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
  }));
}
