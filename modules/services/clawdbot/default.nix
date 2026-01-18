{ inputs, options, config, lib, pkgs, ... }:

with lib;
with lib.my;
let
  cfg = config.modules.services.clawdbot;
  user = config.user.name;
in {
  options.modules.services.clawdbot = {
    enable = mkBoolOpt false;

    telegram = {
      enable = mkBoolOpt false;
      botTokenFile = mkOption {
        type = types.str;
        default = "/Users/${user}/.secrets/telegram-bot-token";
        description = "Path to file containing Telegram bot token";
      };
      allowFrom = mkOption {
        type = types.listOf types.int;
        default = [ ];
        description = "List of Telegram user IDs allowed to interact with bot";
      };
    };

    anthropic = {
      apiKeyFile = mkOption {
        type = types.str;
        default = "/Users/${user}/.secrets/anthropic-api-key";
        description = "Path to file containing Anthropic API key";
      };
    };

    # First-party plugins to enable
    plugins = {
      summarize = mkBoolOpt true;
      peekaboo = mkBoolOpt true;
      oracle = mkBoolOpt true;
      poltergeist = mkBoolOpt true;
      sag = mkBoolOpt true;
      camsnap = mkBoolOpt false;
      gogcli = mkBoolOpt true;
      bird = mkBoolOpt true;
      sonoscli = mkBoolOpt false;
      imsg = mkBoolOpt true;
    };
  };

  config = mkIf cfg.enable {
    # Apply nix-clawdbot overlay to make pkgs.clawdbot available
    nixpkgs.overlays = [ inputs.nix-clawdbot.overlays.default ];

    # Configure clawdbot through home-manager
    home-manager.users.${user}.programs.clawdbot = {
      enable = true;
      documents = ../../config/clawdbot/documents;

      # Use firstParty for built-in plugins (no flake locking needed)
      firstParty = {
        summarize.enable = cfg.plugins.summarize;
        peekaboo.enable = cfg.plugins.peekaboo;
        oracle.enable = cfg.plugins.oracle;
        poltergeist.enable = cfg.plugins.poltergeist;
        sag.enable = cfg.plugins.sag;
        camsnap.enable = cfg.plugins.camsnap;
        gogcli.enable = cfg.plugins.gogcli;
        bird.enable = cfg.plugins.bird;
        sonoscli.enable = cfg.plugins.sonoscli;
        imsg.enable = cfg.plugins.imsg;
      };

      instances.default = {
        enable = true;

        # Anthropic provider (required)
        providers.anthropic.apiKeyFile = cfg.anthropic.apiKeyFile;

        # Telegram provider (optional)
        providers.telegram = mkIf cfg.telegram.enable {
          enable = true;
          botTokenFile = cfg.telegram.botTokenFile;
          allowFrom = cfg.telegram.allowFrom;
          groups."*".requireMention = true;
        };
      };
    };
  };
}
