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
      description = "Gateway auth token (long random string). TODO: upstream tokenFile support";
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

    skills = mkOption {
      type = types.listOf types.attrs;
      default = [ ];
      description = "List of skill configs (name, source, mode)";
    };
  };

  config = mkIf cfg.enable {
    # nix-openclaw overlay applied at flake level (with templates patch)

    # Configure openclaw through home-manager
    home-manager.users.${user} = {
      # Add skill files directly
      home.file = builtins.listToAttrs (map (skill: {
        name = ".openclaw/workspace/skills/${skill.name}/SKILL.md";
        value.text = ''
          ---
          name: ${skill.name}
          description: ${skill.description or ""}
          ---

          ${skill.body or ""}
        '';
      }) cfg.skills);

      programs.openclaw = {
      enable = true;
      # Use patched openclaw-gateway which has templates (workaround for issue #18)
      package = pkgs.openclaw-gateway;
      documents = ../../../config/openclaw/documents;

      # Plugins at top level
      plugins = cfg.plugins;

      # Skills
      skills = cfg.skills;

      # Configure the default instance directly
      instances.default = {
        enable = true;
        # Use patched openclaw-gateway which has templates (workaround for issue #18)
        package = pkgs.openclaw-gateway;
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
      };
    };  # programs.openclaw

      # Add Anthropic API key via ExecStartPre that loads from agenix
      # Use $XDG_RUNTIME_DIR since $(id -u) doesn't work in systemd context
      systemd.user.services.openclaw-gateway.Service = {
        ExecStartPre = [
          "${pkgs.bash}/bin/bash -c 'mkdir -p $XDG_RUNTIME_DIR/openclaw && echo ANTHROPIC_API_KEY=$(cat ${config.age.secrets.anthropic-api-key.path}) > $XDG_RUNTIME_DIR/openclaw/env'"
        ];
        EnvironmentFile = "-/run/user/%U/openclaw/env";
      };
    };  # home-manager.users.${user}
  };
}
