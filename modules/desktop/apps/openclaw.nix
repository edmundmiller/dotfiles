{
  config,
  lib,
  ...
}:

with lib;
with lib.my;
let
  cfg = config.modules.desktop.apps.openclaw;
  user = config.user.name;
in
{
  options.modules.desktop.apps.openclaw = {
    enable = mkBoolOpt false;

    gatewayUrl = mkOption {
      type = types.str;
      default = "ws://nuc.cinnamon-rooster.ts.net:18789";
      description = "WebSocket URL of the remote gateway (Tailscale MagicDNS)";
    };

    gatewayToken = mkOption {
      type = types.str;
      default = "";
      description = "Gateway auth token (must match the gateway's auth.token)";
    };
  };

  config = mkIf cfg.enable {
    # Install OpenClaw.app via Homebrew cask
    homebrew.casks = [ "openclaw" ];

    home-manager.users.${user} = {
      programs.openclaw = {
        enable = true;
        # App installed via Homebrew — don't install via Nix
        installApp = false;
        # No local gateway — Mac is a node only
        launchd.enable = false;
        documents = ../../../config/openclaw/documents;

        instances.default = {
          enable = true;
          # Don't run a local gateway service on the Mac
          launchd.enable = false;
          appDefaults = {
            enable = true;
            nixMode = true;
            attachExistingOnly = true;
          };
          config = {
            gateway = {
              mode = "remote";
              remote = {
                url = cfg.gatewayUrl;
                token = cfg.gatewayToken;
                transport = "direct";
              };
            };
          };
        };
      };
    };
  };
}
