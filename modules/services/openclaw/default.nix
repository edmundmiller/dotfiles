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
  cfg = config.modules.services.openclaw;
  user = config.user.name;
  inherit (config.user) home;

  heartbeat = import ./_heartbeat.nix {
    inherit
      cfg
      lib
      pkgs
      user
      ;
  };

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

  # Gateway doesn't follow symlinks for extension discovery — must be real dirs.
  # Copy from nix store before gateway starts. chmod before rm because previous
  # copies inherit nix store's read-only permissions.
  copyExtensions = pkgs.writeShellScript "openclaw-copy-extensions" ''
    set -euo pipefail
    for ext in ${
      concatMapStringsSep " " (ext: "${ext}/lib/${ext.pname or ext.name}") cfg.gatewayExtensions
    }; do
      name=$(basename "$ext")
      target="$HOME/.openclaw/extensions/$name"
      chmod -R u+w "$target" 2>/dev/null || true
      rm -rf "$target"
      cp -rL "$ext" "$target"
      chmod -R u+w "$target"
    done
  '';

  # Script to inject gateway token + hooks token into config JSON
  mkTokenScript = pkgs.writeShellScript "openclaw-inject-token" ''
    set -euo pipefail
    ${pkgs.gnused}/bin/sed -i \
      "s|__OPENCLAW_TOKEN_PLACEHOLDER__|$(cat ${cfg.gatewayTokenFile})|g" \
      "$HOME/.openclaw/openclaw.json"
    ${optionalString (cfg.hooksTokenFile != "") ''
      ${pkgs.gnused}/bin/sed -i \
        "s|__OPENCLAW_HOOKS_TOKEN_PLACEHOLDER__|$(cat ${cfg.hooksTokenFile})|g" \
        "$HOME/.openclaw/openclaw.json"
    ''}
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

    hooksTokenFile = mkOption {
      type = types.str;
      default = "";
      description = "Path to file containing hooks auth token (agenix secret)";
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
      requireMention = mkOption {
        type = types.bool;
        default = true;
        description = "Whether bot requires @mention in group chats";
      };
      bindings = mkOption {
        type = types.listOf (
          types.submodule {
            options = {
              peerId = mkOption {
                type = types.str;
                description = "Telegram peer user ID (as string)";
              };
              kind = mkOption {
                type = types.enum [
                  "direct"
                  "group"
                ];
                default = "direct";
                description = "Telegram peer kind: direct message or group chat";
              };
              agentId = mkOption {
                type = types.str;
                default = "default";
                description = "OpenClaw agent to route messages to";
              };
            };
          }
        );
        default = [ ];
        description = "Telegram peer → agent bindings (one entry per person)";
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

    claudeMaxProxy = {
      enable = mkBoolOpt false;
      port = mkOption {
        type = types.port;
        default = 3456;
        description = "Port for the Claude Max API proxy";
      };
      package = mkOption {
        type = types.package;
        default = pkgs.my.claude-max-api-proxy;
        description = "claude-max-api-proxy package";
      };
    };

    gatewayExtensions = mkOption {
      type = types.listOf types.package;
      default = [ ];
      description = "Nix packages to symlink into ~/.openclaw/extensions/ (gateway npm extensions)";
    };

    heartbeatMonitor = heartbeat.options;

    webhookProxy = {
      enable = mkBoolOpt false;
      funnelPort = mkOption {
        type = types.port;
        default = 8443;
        description = "Tailscale Funnel port (public). Must be 443, 8443, or 10000.";
      };
      nginxPort = mkOption {
        type = types.port;
        default = 8444;
        description = "Internal nginx listen port (loopback only)";
      };
      gatewayPort = mkOption {
        type = types.port;
        default = 18789;
        description = "OpenClaw gateway HTTP port to proxy to";
      };
    };
  };

  config = mkIf cfg.enable (mkMerge [
    # NixOS-only: nginx proxy, systemd services, firewall
    (optionalAttrs (!isDarwin) {
      # Webhook proxy: nginx (method-restricted) + Tailscale Funnel (path-restricted)
      # Exposes ONLY POST /plugins/linear/* to the public internet on a separate port.
      # The gateway stays tailnet-only on port 443.
      services.nginx = mkIf cfg.webhookProxy.enable {
        enable = true;
        appendHttpConfig = ''
          server {
            listen 127.0.0.1:${toString cfg.webhookProxy.nginxPort};
            server_name _;

            # Tailscale funnel --set-path=/plugins/linear strips the prefix,
            # so /plugins/linear/linear arrives here as just /linear.
            # Re-add the prefix when proxying to the gateway.
            location / {
              limit_except POST { deny all; }
              proxy_pass http://127.0.0.1:${toString cfg.webhookProxy.gatewayPort}/plugins/linear/;
              proxy_set_header Host $host;
              proxy_set_header X-Real-IP $remote_addr;
              proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
              proxy_set_header X-Forwarded-Proto https;
              proxy_read_timeout 120s;
              client_max_body_size 1m;
            }
          }
        '';
      };

      # Tailscale Funnel — expose webhook path on port 8443 (public internet)
      # Port 443 stays as Serve (tailnet-only) for the full gateway.
      # First-time setup requires interactive approval in Tailscale admin console.
      systemd.services.tailscale-funnel-linear = mkIf cfg.webhookProxy.enable {
        description = "Tailscale Funnel for Linear webhook proxy";
        after = [
          "tailscaled.service"
          "nginx.service"
          "network-online.target"
        ];
        requires = [ "tailscaled.service" ];
        wants = [
          "nginx.service"
          "network-online.target"
        ];
        wantedBy = [ "multi-user.target" ];
        path = [ pkgs.tailscale ];
        script = ''
          # Wait for tailscale to be connected
          while ! tailscale status >/dev/null 2>&1; do sleep 2; done

          # Expose via funnel (public internet) on funnel port, path-restricted
          # funnel = serve + public access; --bg makes it persistent (exit after config)
          tailscale funnel --bg --https=${toString cfg.webhookProxy.funnelPort} \
            --set-path=/plugins/linear \
            http://127.0.0.1:${toString cfg.webhookProxy.nginxPort}
        '';
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          ExecStop = "${pkgs.tailscale}/bin/tailscale funnel reset";
        };
      };

      # Open the funnel port in the firewall
      networking.firewall.allowedTCPPorts = mkIf cfg.webhookProxy.enable [
        cfg.webhookProxy.funnelPort
      ];
    })

    {
      # Source openclaw secrets env file so CLI commands (openclaw status, etc)
      # get the same API keys as the systemd service. Uses envInit (.zshenv)
      # so it works for non-interactive shells too (e.g. ssh nuc "openclaw status").
      modules.shell.zsh.envInit = ''
        if [[ -f "''${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/openclaw/env" ]]; then
          set -a  # auto-export so child processes (openclaw CLI) inherit the vars
          source "''${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/openclaw/env"
          set +a
        fi
      '';

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

            exposePluginPackages = true;

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
                citations = "auto";
                # QMD available for Obsidian vault search (not primary memory backend)
                qmd.command = "${home}/.local/bin/qmd-wrapper";
              };

              plugins = {
                slots.memory = "memory-lancedb";
                entries."memory-lancedb" = {
                  enabled = true;
                  config = {
                    embedding = {
                      apiKey = "\${OPENAI_API_KEY}";
                      model = "text-embedding-3-small";
                    };
                    dbPath = "${home}/.openclaw/memory/lancedb";
                    autoCapture = true;
                    autoRecall = true;
                  };
                };
              };

              agents.defaults = {
                model = {
                  # anthropic native API avoids openai-completions adapter phantom tool bug
                  # (openclaw#23116, openclaw#21985) that corrupts MiniMax/Kimi sessions
                  primary = "anthropic/claude-sonnet-4-5";
                  fallbacks = [
                    "claude-max/claude-sonnet-4"
                    "opencode/minimax-m2.5"
                  ];
                };
                thinkingDefault = "high";
                heartbeat.model = "anthropic/claude-haiku-4";
                subagents.model = {
                  primary = "anthropic/claude-sonnet-4-5";
                  fallbacks = [
                    "claude-max/claude-sonnet-4"
                    "opencode/minimax-m2.5"
                  ];
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
                  host = "gateway";
                  security = "full";
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

              bindings = map (b: {
                inherit (b) agentId;
                match = {
                  channel = "telegram";
                  peer = {
                    id = b.peerId;
                    inherit (b) kind;
                  };
                };
              }) cfg.telegram.bindings;

              # Claude Max proxy — exposes subscription as OpenAI-compatible API.
              # Models available as claude-max/claude-opus-4, claude-max/claude-sonnet-4, etc.
              models = mkIf cfg.claudeMaxProxy.enable {
                providers.claude-max = {
                  baseUrl = "http://localhost:${toString cfg.claudeMaxProxy.port}/v1";
                  apiKey = "not-needed";
                  api = "openai-completions";
                  models = [
                    {
                      id = "claude-opus-4";
                      name = "Claude Opus 4";
                    }
                    {
                      id = "claude-sonnet-4";
                      name = "Claude Sonnet 4";
                    }
                    {
                      id = "claude-haiku-4";
                      name = "Claude Haiku 4";
                    }
                  ];
                };
              };

              # OpenCode Zen models — use built-in catalog for per-model API routing + costs.
              # OPENCODE_API_KEY is injected via secrets env file; the gateway auto-discovers
              # Zen models (minimax-m2.5, kimi-k2.5 etc) when the key is present.

              hooks = mkIf (cfg.hooksTokenFile != "") {
                enabled = true;
                token = "__OPENCLAW_HOOKS_TOKEN_PLACEHOLDER__";
                defaultSessionKey = "hook:ingress";
                allowRequestSessionKey = false;
              };

              channels.telegram = mkIf cfg.telegram.enable {
                tokenFile = cfg.telegram.botTokenFile;
                inherit (cfg.telegram) allowFrom;
                groups."*".requireMention = cfg.telegram.requireMention;
              };
            };
          };

          # Claude Max API proxy — runs alongside gateway, exposes subscription as OpenAI API
          systemd.user.services.claude-max-api-proxy = mkIf cfg.claudeMaxProxy.enable {
            Unit = {
              Description = "Claude Max API Proxy (OpenAI-compatible)";
              StartLimitIntervalSec = 60;
              StartLimitBurst = 5;
            };
            Install.WantedBy = [ "default.target" ];
            Service = {
              ExecStart = "${cfg.claudeMaxProxy.package}/bin/claude-max-api ${toString cfg.claudeMaxProxy.port}";
              Restart = "on-failure";
              RestartSec = 5;
              # claude CLI needs PATH to find itself + node
              Environment = "PATH=/run/current-system/sw/bin:/etc/profiles/per-user/${user}/bin";
            };
          };

          # Inject agenix secrets + gateway token via ExecStartPre
          systemd.user.services.openclaw-gateway.Unit = mkMerge [
            {
              # Relax start rate limit — deploys restart user services and openclaw
              # takes a few seconds to boot, hitting the default 5/10s limit
              StartLimitIntervalSec = 60;
              StartLimitBurst = 10;
            }
            (mkIf cfg.claudeMaxProxy.enable {
              After = [ "claude-max-api-proxy.service" ];
              Requires = [ "claude-max-api-proxy.service" ];
            })
          ];
          systemd.user.services.openclaw-gateway.Install = {
            WantedBy = [ "default.target" ];
          };
          systemd.user.services.openclaw-gateway.Service =
            let
              # memory-lancedb extension needs openai + @lancedb/lancedb from the
              # gateway's pnpm store — the Nix build leaves extension node_modules
              # empty (upstream packaging bug). This script finds the deps in the
              # pnpm virtual store and appends NODE_PATH to the env file.
              findNodePath = pkgs.writeShellScript "openclaw-node-path" ''
                set -euo pipefail
                GW_STORE=$(readlink -f $(which openclaw) | sed 's|/bin/openclaw$||')
                PNPM="$GW_STORE/lib/openclaw/node_modules/.pnpm"

                OPENAI_DIR=$(find "$PNPM" -maxdepth 2 -path '*/openai@*/node_modules' -type d 2>/dev/null | head -1)
                LANCE_DIR=$(find "$PNPM" -maxdepth 2 -path '*/@lancedb+lancedb@*/node_modules' -type d 2>/dev/null | head -1)

                NODE_PATH=""
                [ -n "$OPENAI_DIR" ] && NODE_PATH="$OPENAI_DIR"
                [ -n "$LANCE_DIR" ] && NODE_PATH="''${NODE_PATH:+$NODE_PATH:}$LANCE_DIR"

                mkdir -p "$XDG_RUNTIME_DIR/openclaw"
                echo "NODE_PATH=$NODE_PATH" >> "$XDG_RUNTIME_DIR/openclaw/env"
              '';
            in
            {
              ExecStartPre = [
                "${mkEnvScript}"
                "${pkgs.bash}/bin/bash ${mkTokenScript}"
                "${findNodePath}"
                "${copyExtensions}"
              ];
              EnvironmentFile = "-/run/user/%U/openclaw/env";
            };
        };
    }

    # External heartbeat monitors — per-agent systemd timers trigger heartbeat + healthchecks.io
    # Lives outside the gateway process so it detects gateway crashes/hangs.
    (optionalAttrs (!isDarwin) {
      home-manager.users.${user} = {
        systemd.user.services = heartbeat.services;
        systemd.user.timers = heartbeat.timers;
      };
    })
  ]);
}
