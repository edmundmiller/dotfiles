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
  home = config.user.home;

  # Script to inject agenix secrets into systemd env file
  mkEnvScript = pkgs.writeShellScript "openclaw-env" ''
    set -euo pipefail
    mkdir -p "$XDG_RUNTIME_DIR/openclaw"
    {
      ${concatMapStringsSep "\n      " (
        secret:
        if secret.literal or false then
          "echo ${secret.envVar}=${secret.value}"
        else
          ''echo ${secret.envVar}="$(cat ${secret.path})"''
      ) cfg.secrets}
    } > "$XDG_RUNTIME_DIR/openclaw/env"
  '';

  # Script to inject gateway token into config JSON
  mkTokenScript = pkgs.writeShellScript "openclaw-inject-token" ''
    set -euo pipefail
    ${pkgs.gnused}/bin/sed -i \
      "s|__OPENCLAW_TOKEN_PLACEHOLDER__|$(cat ${cfg.gatewayTokenFile})|g" \
      "$HOME/.openclaw/openclaw.json"
  '';
in
{
  options.modules.services.openclaw = {
    enable = mkBoolOpt false;

    gatewayTokenFile = mkOption {
      type = types.str;
      default = "";
      description = "Path to file containing gateway auth token (agenix secret)";
    };

    secrets = mkOption {
      type = types.listOf (
        types.submodule {
          options = {
            envVar = mkOption {
              type = types.str;
              description = "Environment variable name";
            };
            path = mkOption {
              type = types.str;
              default = "";
              description = "Path to agenix secret file (read at runtime)";
            };
            value = mkOption {
              type = types.str;
              default = "";
              description = "Literal value (use instead of path for non-secret values)";
            };
            literal = mkOption {
              type = types.bool;
              default = false;
              description = "If true, use value directly instead of reading from path";
            };
          };
        }
      );
      default = [ ];
      description = "Env vars injected via ExecStartPre (from agenix files or literal values)";
    };

    telegram = {
      enable = mkBoolOpt false;
      botTokenFile = mkOption {
        type = types.str;
        default = "${home}/.secrets/telegram-bot-token";
        description = "Path to file containing Telegram bot token";
      };
      allowFrom = mkOption {
        type = types.listOf types.int;
        default = [ ];
        description = "List of Telegram user IDs allowed to interact with bot";
      };
    };

    customPlugins = mkOption {
      type = types.listOf types.attrs;
      default = [ ];
      description = "Custom plugin configs with { source = \"github:...\"; }";
    };

    skills = mkOption {
      type = types.listOf types.attrs;
      default = [ ];
      description = "List of skill configs (name, source, mode)";
    };

    sharedSkills = mkOption {
      type = types.listOf types.str;
      default = [ ];
      description = "Skill names to cherry-pick from agent-skills bundle";
    };
  };

  config = mkIf cfg.enable {
    home-manager.users.${user} =
      let
        hmCfg = config.home-manager.users.${user};
        bundle = hmCfg.programs.agent-skills.bundlePath;

        inlineSkillFiles = listToAttrs (
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
        );

        sharedSkillFiles = listToAttrs (
          map (name: {
            name = ".openclaw/workspace/skills/${name}";
            value.source = "${bundle}/${name}";
          }) cfg.sharedSkills
        );
      in
      {
        home.file =
          inlineSkillFiles
          // sharedSkillFiles
          // {
            # Force-overwrite — openclaw mutates config at runtime, breaking home-manager backups
            ".openclaw/openclaw.json".force = true;
          };

        programs.openclaw = {
          enable = true;
          package = pkgs.openclaw-gateway;
          documents = ./documents;
          inherit (cfg) customPlugins skills;

          # Avoid libexec/node_modules conflict between oracle+summarize
          exposePluginPackages = false;

          bundledPlugins.sag = {
            enable = true;
            config.env.ELEVENLABS_API_KEY_FILE = config.age.secrets.elevenlabs-api-key.path;
          };

          # Config goes at top level — upstream auto-creates default instance and merges this in
          config = {
            gateway = {
              mode = "local";
              bind = "loopback";
              tailscale.mode = "serve";
              trustedProxies = [
                "127.0.0.1"
                "::1"
              ];
              auth = {
                token = "__OPENCLAW_TOKEN_PLACEHOLDER__";
                allowTailscale = true;
              };
            };

            memory = {
              backend = "lancedb";
              citations = "auto";
              lancedb = {
                embedding = {
                  apiKey = "\${OPENAI_API_KEY}";
                  model = "text-embedding-3-small";
                };
                dbPath = "${home}/.openclaw/memory/lancedb";
                autoCapture = true;
                autoRecall = true;
              };
              # QMD still available for Obsidian vault search
              qmd.command = "${home}/.local/bin/qmd-wrapper";
            };

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
            };

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

            channels.telegram = mkIf cfg.telegram.enable {
              tokenFile = cfg.telegram.botTokenFile;
              inherit (cfg.telegram) allowFrom;
              groups."*".requireMention = true;
            };
          };
        };

        # Inject agenix secrets + gateway token via ExecStartPre
        systemd.user.services.openclaw-gateway.Service = {
          ExecStartPre = [
            "${mkEnvScript}"
            "${pkgs.bash}/bin/bash ${mkTokenScript}"
          ];
          EnvironmentFile = "-/run/user/%U/openclaw/env";
        };
      };
  };
}
