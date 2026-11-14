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
  cfg = config.modules.services.plannotator;
  dataDir = "${config.user.home}/.plannotator";
in
{
  options.modules.services.plannotator = {
    enable = mkBoolOpt false;
    allowedLogins = mkOpt (types.listOf types.str) [ ];
  };

  config = optionalAttrs (!isDarwin) (
    mkIf cfg.enable {
      assertions = [
        {
          assertion = config.modules.agents.plannotator.enable;
          message = "The Plannotator Inbox service requires modules.agents.plannotator.enable.";
        }
        {
          assertion = cfg.allowedLogins != [ ];
          message = "The Plannotator Inbox requires explicit Tailscale logins on a tagged host.";
        }
      ];

      # Use the same home as interactive Pi and Amp. The upstream tailnet
      # listener checks login identity and does not expose the local MCP port.
      systemd.services.plannotator-inbox = {
        description = "Plannotator Inbox over Tailscale";
        wantedBy = [ "multi-user.target" ];
        wants = [ "tailscaled.service" ];
        after = [
          "network-online.target"
          "tailscaled.service"
        ];
        path = [
          pkgs.tailscale
          pkgs.git
          "/etc/profiles/per-user/${config.user.name}"
        ];
        environment = {
          HOME = config.user.home;
          PLANNOTATOR_INBOX_TOOL = "1";
          PLANNOTATOR_INBOX_TAILSCALE = "1";
          PLANNOTATOR_INBOX_CONNECT = "0";
          PLANNOTATOR_INBOX_NOTES = "0";
          PLANNOTATOR_AUTO_UPDATE = "0";
        };
        preStart = ''
          set -eu
          install -d -m 0700 ${escapeShellArg dataDir}
          cd ${escapeShellArg dataDir}
          temporary="$(mktemp config.json.XXXXXX)"
          trap 'rm -f "$temporary"' EXIT
          source=/dev/null
          if [ -f config.json ]; then source=config.json; fi
          ${pkgs.jq}/bin/jq -s --argjson logins ${escapeShellArg (builtins.toJSON cfg.allowedLogins)} '
            (if length == 0 then {} else .[0] end)
            | if type != "object" then error("Plannotator config must be an object") else . end
            | .inboxTailscaleAllow = $logins
          ' "$source" > "$temporary"
          chmod 0600 "$temporary"
          mv "$temporary" config.json
        '';
        serviceConfig = {
          User = config.user.name;
          WorkingDirectory = config.user.home;
          ExecStart = "${lib.getExe config.modules.agents.plannotator.package} inbox --no-open";
          Restart = "always";
          RestartSec = "5s";
          UMask = "0077";
        };
      };
    }
  );
}
