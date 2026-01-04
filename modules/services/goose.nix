# Goose AI agent web server for iOS app connectivity
# Uses Tailscale serve for HTTPS termination (required for iOS App Transport Security)
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
  cfg = config.modules.services.goose;

  # Goose config with Anthropic provider
  gooseConfig = pkgs.writeText "goose-config.yaml" ''
    GOOSE_PROVIDER: anthropic
    GOOSE_MODEL: claude-sonnet-4-20250514
  '';
in
{
  options.modules.services.goose = {
    enable = mkBoolOpt false;
    port = mkOpt types.port 3000;
    httpsPort = mkOpt types.port 3002; # External HTTPS port via Tailscale serve
    host = mkOpt types.str "127.0.0.1"; # Bind to localhost, Tailscale serve handles external access
  };

  config = mkIf cfg.enable (optionalAttrs (!isDarwin) {
    # Secrets auto-loaded from hosts/nuc/secrets/secrets.nix via modules/agenix.nix

    # Ensure goose config directory exists with provider config
    systemd.tmpfiles.rules = [
      "d /home/emiller/.config/goose 0755 emiller users -"
      "L+ /home/emiller/.config/goose/config.yaml - - - - ${gooseConfig}"
    ];

    # Main goose web server (HTTP on localhost)
    systemd.services.goose = {
      wantedBy = [ "multi-user.target" ];
      description = "Goose AI agent web server";
      after = [
        "network.target"
        "tailscaled.service"
        "systemd-tmpfiles-setup.service"
      ];
      wants = [ "tailscaled.service" ];
      serviceConfig = {
        ExecStart = "${pkgs.writeShellScript "goose-web" ''
          export ANTHROPIC_API_KEY=$(cat ${config.age.secrets.anthropic-api-key.path})
          exec ${lib.getExe pkgs.goose-cli} web --port ${toString cfg.port} --host ${cfg.host}
        ''}";
        User = "emiller";
        Group = "users";
        WorkingDirectory = "/home/emiller";
        Environment = [
          "HOME=/home/emiller"
          "XDG_CONFIG_HOME=/home/emiller/.config"
        ];
        Restart = "on-failure";
        RestartSec = "10s";
      };
    };

    # Tailscale serve for HTTPS termination (required for iOS)
    # Proxies https://<tailscale-hostname>:3002 -> http://localhost:3000
    systemd.services.goose-tailscale-serve = {
      wantedBy = [ "multi-user.target" ];
      description = "Tailscale HTTPS proxy for Goose";
      after = [ "goose.service" "tailscaled.service" ];
      wants = [ "goose.service" ];
      serviceConfig = {
        ExecStart = "${pkgs.tailscale}/bin/tailscale serve --bg --https ${toString cfg.httpsPort} http://localhost:${toString cfg.port}";
        ExecStop = "${pkgs.tailscale}/bin/tailscale serve reset";
        Type = "oneshot";
        RemainAfterExit = true;
      };
    };

    environment.systemPackages = [ pkgs.goose-cli ];

    # No need to open firewall - Tailscale handles it
  });
}
