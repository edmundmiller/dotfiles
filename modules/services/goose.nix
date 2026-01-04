# Goose AI agent web server for iOS app connectivity
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
    host = mkOpt types.str "0.0.0.0"; # Bind to all interfaces for Tailscale access
  };

  config = mkIf cfg.enable (optionalAttrs (!isDarwin) {
    # Secrets auto-loaded from hosts/nuc/secrets/secrets.nix via modules/agenix.nix

    # Ensure goose config directory exists with provider config
    systemd.tmpfiles.rules = [
      "d /home/emiller/.config/goose 0755 emiller users -"
      "L+ /home/emiller/.config/goose/config.yaml - - - - ${gooseConfig}"
    ];

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
          AUTH_TOKEN=$(cat ${config.age.secrets.goose-auth-token.path})
          exec ${lib.getExe pkgs.goose-cli} web --port ${toString cfg.port} --host ${cfg.host} --auth-token "$AUTH_TOKEN"
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

    environment.systemPackages = [ pkgs.goose-cli ];

    # Firewall opened for Tailscale access
    networking.firewall.allowedTCPPorts = [ cfg.port ];
  });
}
