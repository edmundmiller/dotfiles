{ inputs, options, config, lib, pkgs, ... }:

with lib;
with lib.my;
let
  cfg = config.modules.services.openclaw;
  user = config.user.name;
in {
  options.modules.services.openclaw = {
    enable = mkBoolOpt false;

    gatewayToken = mkOption {
      type = types.str;
      default = "";
      description = "Gateway auth token (long random string)";
    };

    telegram = {
      enable = mkBoolOpt false;
      botTokenFile = mkOption {
        type = types.str;
        default = "${config.user.home}/.secrets/telegram-bot-token";
        description = "Path to file containing Telegram bot token";
      };
      allowFrom = mkOption {
        type = types.listOf types.int;
        default = [ ];
        description = "List of Telegram user IDs allowed to interact with bot";
      };
    };

    plugins = mkOption {
      type = types.listOf types.attrs;
      default = [ ];
      description = "List of plugin configs with { source = \"github:...\"; }";
    };
  };

  config = mkIf cfg.enable {
    # Apply nix-openclaw overlay
    nixpkgs.overlays = [ inputs.nix-openclaw.overlays.default ];

    # Configure openclaw through home-manager
    home-manager.users.${user}.programs.openclaw = {
      enable = true;
      documents = ../../../config/openclaw/documents;

      config = {
        gateway = {
          mode = "local";
          auth.token = cfg.gatewayToken;
        };

        channels.telegram = mkIf cfg.telegram.enable {
          tokenFile = cfg.telegram.botTokenFile;
          allowFrom = cfg.telegram.allowFrom;
          groups."*".requireMention = true;
        };
      };

      instances.default = {
        enable = true;
        plugins = cfg.plugins;
      };
    };
  };
}
