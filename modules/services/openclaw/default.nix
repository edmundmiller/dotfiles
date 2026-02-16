{
  config,
  lib,
  pkgs,
  ...
}:

with lib;
with lib.my;
let
  cfg = config.modules.services.openclaw;
  user = config.user.name;
in
{
  options.modules.services.openclaw = {
    enable = mkBoolOpt false;

    gatewayTokenFile = mkOption {
      type = types.str;
      default = "";
      description = "Path to file containing gateway auth token (agenix secret)";
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

    firstParty = mkOption {
      type = types.attrs;
      default = { };
      description = "First-party plugin toggles passed to programs.openclaw.firstParty.";
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
      home.file =
        builtins.listToAttrs (
          map (skill: {
            name = ".openclaw/workspace/skills/${skill.name}/SKILL.md";
            value.text = ''
              ---
              name: ${skill.name}
              description: ${skill.description or ""}
              ---

              ${skill.body or ""}
            '';
          }) cfg.skills
        )
        // {
          # Force-overwrite — openclaw mutates config at runtime, breaking home-manager backups
          ".openclaw/openclaw.json".force = true;
        };

      programs.openclaw = {
        enable = true;
        # Use patched openclaw-gateway which has templates (workaround for issue #18)
        package = pkgs.openclaw-gateway;
        documents = ../../../config/openclaw/documents;

        # Plugins at top level
        inherit (cfg) plugins;
        inherit (cfg) firstParty;

        # Skills
        inherit (cfg) skills;

        # exposePluginPackages = false avoids libexec/node_modules conflict between oracle+summarize
        exposePluginPackages = false;

        # Enable sag (TTS) plugin
        bundledPlugins.sag = {
          enable = true;
          config = {
            env.ELEVENLABS_API_KEY_FILE = config.age.secrets.elevenlabs-api-key.path;
          };
        };

        # Configure the default instance directly
        instances.default = {
          enable = true;
          # Use patched openclaw-gateway which has templates (workaround for issue #18)
          package = pkgs.openclaw-gateway;
          config = {
            gateway = {
              mode = "local";
              # GP2: loopback + Tailscale Serve (HTTPS via MagicDNS)
              bind = "loopback";
              tailscale.mode = "serve";
              # Tailscale Serve proxies from loopback — must be trusted for identity headers
              trustedProxies = [
                "127.0.0.1"
                "::1"
              ];
              auth = {
                token = "__OPENCLAW_TOKEN_PLACEHOLDER__";
                allowTailscale = true;
              };
            };

            # --- Memory ---
            memory = {
              backend = "qmd";
              citations = "auto";
            };

            # --- Agents ---
            agents.defaults = {
              model = {
                primary = "opencode/minimax-m2.5";
                fallbacks = [ "anthropic/claude-sonnet-4-5" ];
              };
              thinkingDefault = "high";
              heartbeat.model = "opencode/minimax-m2.5";
              subagents.model = {
                primary = "opencode/minimax-m2.5";
                fallbacks = [ "anthropic/claude-haiku-4" ];
              };

              # CLI backends — pi, claude, codex
              cliBackends = {
                pi = {
                  command = "bunx";
                  args = [
                    "@mariozechner/pi-coding-agent"
                    "--print"
                  ];
                  input = "arg";
                  output = "text";
                };
                claude = {
                  command = "claude";
                  args = [ "--print" ];
                  input = "arg";
                  output = "text";
                };
                codex = {
                  command = "codex";
                  input = "arg";
                  output = "text";
                };
              };

              # Tools — full profile, exec allowlist
              tools = {
                profile = "full";
                exec = {
                  security = "allowlist";
                  safeBins = [
                    "cat"
                    "ls"
                    "find"
                    "grep"
                    "rg"
                    "jq"
                    "curl"
                    "git"
                    "head"
                    "tail"
                    "wc"
                    "sort"
                    "uniq"
                    "sed"
                    "awk"
                    "echo"
                    "mkdir"
                    "cp"
                    "mv"
                    "rm"
                    "touch"
                    "chmod"
                    "dirname"
                    "basename"
                    "realpath"
                    "which"
                    "env"
                    "date"
                    "diff"
                    "tr"
                    "tee"
                    "xargs"
                  ];
                };
              };
            };

            # --- Bindings: main agent → telegram ---
            bindings = [
              {
                agentId = "default";
                match = {
                  channel = "telegram";
                  peer = {
                    id = "8357890648";
                    kind = "direct";
                  };
                };
              }
            ];

            models.providers.opencode = {
              baseUrl = "https://opencode.ai/zen/v1";
              apiKey = "\${OPENCODE_API_KEY}";
              api = "openai-completions";
              models = [
                {
                  id = "minimax-m2.5";
                  name = "MiniMax M2.5";
                  cost = {
                    input = 0.30;
                    output = 1.20;
                    cacheRead = 0.06;
                    cacheWrite = 0.15;
                  };
                }
                {
                  id = "kimi-k2.5";
                  name = "Kimi K2.5";
                }
              ];
            };
            # Built-in OpenCode catalog handles Zen routing + cost tracking
            channels.telegram = mkIf cfg.telegram.enable {
              tokenFile = cfg.telegram.botTokenFile;
              inherit (cfg.telegram) allowFrom;
              groups."*".requireMention = true;
            };
          };
        };
      }; # programs.openclaw

      # Add API keys via ExecStartPre that loads from agenix
      # Use $XDG_RUNTIME_DIR since $(id -u) doesn't work in systemd context
      systemd.user.services.openclaw-gateway.Service = {
        ExecStartPre = [
          "${pkgs.bash}/bin/bash -c 'mkdir -p $XDG_RUNTIME_DIR/openclaw && { echo ANTHROPIC_API_KEY=$(cat ${config.age.secrets.anthropic-api-key.path}); echo OPENCODE_API_KEY=$(cat ${config.age.secrets.opencode-api-key.path}); echo OPENAI_API_KEY=$(cat ${config.age.secrets.openai-api-key.path}); echo ELEVENLABS_API_KEY=$(cat ${config.age.secrets.elevenlabs-api-key.path}); echo GOG_KEYRING_PASSWORD=gogcli-agenix; } > $XDG_RUNTIME_DIR/openclaw/env'"
          # Inject gateway token from agenix into openclaw.json
          "${pkgs.bash}/bin/bash -c '${pkgs.gnused}/bin/sed -i \"s|__OPENCLAW_TOKEN_PLACEHOLDER__|$(cat ${config.age.secrets.openclaw-gateway-token.path})|g\" $HOME/.openclaw/openclaw.json'"
        ];
        EnvironmentFile = "-/run/user/%U/openclaw/env";
      };
    }; # home-manager.users.${user}
  };
}
