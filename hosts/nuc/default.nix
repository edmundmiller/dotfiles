# Go nuc yourself (2026-02-26)
{
  config,
  inputs,
  pkgs,
  system,
  ...
}:
let
  linearTokenFile = "/home/emiller/.local/state/openclaw-linear/token";

  linearTokenRefreshScript = pkgs.writeShellScript "linear-token-refresh" ''
    set -euo pipefail
    # Read refresh token — prefer persisted (rotated) token, fall back to agenix seed
    REFRESH_FILE="''${STATE_DIRECTORY}/refresh-token"
    if [ -s "$REFRESH_FILE" ]; then
      REFRESH_TOKEN=$(cat "$REFRESH_FILE")
    else
      REFRESH_TOKEN=$(cat /run/agenix/linear-refresh-token)
    fi
    CLIENT_ID="c64c969674a02fccc863d4aa950ec132"
    CLIENT_SECRET="72406896af1a83cb5765c6042a59cde2"

    RESPONSE=$(${pkgs.curl}/bin/curl -sf -X POST https://api.linear.app/oauth/token \
      -H "Content-Type: application/x-www-form-urlencoded" \
      --data-urlencode "grant_type=refresh_token" \
      --data-urlencode "client_id=$CLIENT_ID" \
      --data-urlencode "client_secret=$CLIENT_SECRET" \
      --data-urlencode "refresh_token=$REFRESH_TOKEN")

    ACCESS_TOKEN=$(echo "$RESPONSE" | ${pkgs.jq}/bin/jq -r '.access_token')
    NEW_REFRESH=$(echo "$RESPONSE" | ${pkgs.jq}/bin/jq -r '.refresh_token // empty')
    if [ "$ACCESS_TOKEN" = "null" ] || [ -z "$ACCESS_TOKEN" ]; then
      echo "Failed to refresh Linear token: $RESPONSE" >&2
      exit 1
    fi

    echo -n "$ACCESS_TOKEN" > "''${STATE_DIRECTORY}/token"
    # Linear rotates refresh tokens — persist the new one for next refresh
    if [ -n "$NEW_REFRESH" ]; then
      echo -n "$NEW_REFRESH" > "$REFRESH_FILE"
    fi
    echo "Linear OAuth token refreshed"
  '';

in
{
  # Workaround for nix-openclaw using bare commands (cat, ln, mkdir, rm)
  # TODO: Report upstream to nix-openclaw
  system.activationScripts.binCompat = ''
    mkdir -p /bin
    for cmd in cat ln mkdir rm; do
      ln -sf ${pkgs.coreutils}/bin/$cmd /bin/$cmd
    done

  '';

  # Allow __noChroot derivations (e.g. qmd needs network for bun install)
  nix.settings.sandbox = "relaxed";

  # nix-ld for dynamically linked binaries (e.g. sag TTS)
  programs.nix-ld = {
    enable = true;
    libraries = with pkgs; [
      alsa-lib # libasound.so.2 for sag audio playback
    ];
  };

  home-manager.users.${config.user.name} = {
    # Disable dconf on headless server - no dbus session available
    dconf.enable = false;
    # Ensure systemd user services can find system + user packages (openclaw uses bare 'cat')
    systemd.user.sessionVariables.PATH = "/bin:/run/current-system/sw/bin:/etc/profiles/per-user/${config.user.name}/bin";

    # linear-token-init: ensures token file exists before openclaw-gateway starts.
    # RemainAfterExit=yes so gateway restarts don't re-trigger it unnecessarily.
    systemd.user.services.linear-token-init = {
      Unit = {
        Description = "Initialize Linear OAuth token file";
        Before = "openclaw-gateway.service";
      };
      Install.WantedBy = [ "openclaw-gateway.service" ];
      Service = {
        Type = "oneshot";
        RemainAfterExit = "yes";
        StateDirectory = "openclaw-linear";
        ExecStart = toString linearTokenRefreshScript;
      };
    };

    # linear-token-refresh: timer-driven periodic refresh (every 12h).
    # Restarts openclaw-gateway after updating the token so the new value is picked up.
    systemd.user.services.linear-token-refresh = {
      Unit.Description = "Refresh Linear OAuth access token";
      Service = {
        Type = "oneshot";
        StateDirectory = "openclaw-linear";
        ExecStart = toString linearTokenRefreshScript;
        ExecStartPost = "${pkgs.systemd}/bin/systemctl --user try-restart openclaw-gateway.service";
      };
    };
    systemd.user.timers.linear-token-refresh = {
      Unit.Description = "Refresh Linear OAuth token every 12h";
      Timer = {
        OnUnitActiveSec = "12h";
        RandomizedDelaySec = "5min";
      };
      Install.WantedBy = [ "timers.target" ];
    };

    # linear-agent-bridge gateway extension config
    programs.openclaw.config.plugins.entries.linear-agent-bridge = {
      enabled = true;
      config = {
        linearApiKey = "\${LINEAR_API_KEY}";
        linearWebhookSecret = "\${LINEAR_WEBHOOK_SECRET}";
        devAgentId = "main";
        enableAgentApi = true;
        # Agent callbacks stay local — no need to go through funnel
        apiBaseUrl = "http://127.0.0.1:18789/plugins/linear/api";
      };
    };
  };

  environment.systemPackages = with pkgs; [
    taskwarrior3
    sqlite
    chromium # For openclaw browser
    nodejs # For openclaw plugins
    python3 # For node-gyp (pi-interactive-shell/node-pty)
    gcc
    gnumake # For node-gyp native compilation
    cmake # For node-llama-cpp (qmd dependency)
    claude-code # CLI backend for openclaw
    codex # CLI backend for openclaw
    bun # For pi CLI backend (npm: @mariozechner/pi-coding-agent)
    uv # For vault sync scripts (PEP 723 inline deps)
    home-assistant-cli # hass-cli: agent-friendly HA REST API wrapper
    inputs.nix-steipete-tools.packages.${system}.sag # TTS for openclaw sag plugin
    # qmd installed globally via npm (nix-built version has read-only store issues with node-llama-cpp)
  ];
  imports = [
    ../_server.nix
    ../_home.nix
    ./hardware-configuration.nix
    ./disko.nix
    ./backups.nix
  ];

  ## Modules
  modules = {
    editors = {
      default = "nvim";
      vim.enable = true;
    };
    hardware = {
      bluetooth.enable = true;
      fs = {
        enable = true;
        zfs.enable = true;
        ssd.enable = true;
      };
    };
    dev = {
      node = {
        enable = true;
        enableGlobally = true;
      };
    };
    shell = {
      # bugwarrior.enable = false;  # Module removed
      git.enable = true;
      tmux.enable = true;
      zsh.enable = true;
      pi.enable = true;
      ai = {
        enable = true;
        enableClaude = true;
        enableCodex = true;
      };

    };
    services = {
      audiobookshelf.enable = true;
      openclaw = {
        enable = true;
        claudeMaxProxy.enable = false;
        gatewayTokenFile = config.age.secrets.openclaw-gateway-token.path;
        hooksTokenFile = config.age.secrets.openclaw-hooks-token.path;
        secrets = [
          {
            envVar = "ANTHROPIC_API_KEY";
            inherit (config.age.secrets.anthropic-api-key) path;
          }
          {
            envVar = "OPENCODE_API_KEY";
            inherit (config.age.secrets.opencode-api-key) path;
          }
          {
            envVar = "OPENAI_API_KEY";
            inherit (config.age.secrets.openai-api-key) path;
          }
          {
            envVar = "ELEVENLABS_API_KEY";
            inherit (config.age.secrets.elevenlabs-api-key) path;
          }
          {
            envVar = "LINEAR_API_KEY";
            path = linearTokenFile;
          }
          {
            envVar = "LINEAR_WEBHOOK_SECRET";
            inherit (config.age.secrets.linear-webhook-secret) path;
          }
          {
            envVar = "HC_PING_KEY";
            inherit (config.age.secrets.healthchecks-ping-key) path;
          }
          {
            envVar = "HC_API_KEY";
            inherit (config.age.secrets.healthchecks-api-key) path;
          }
          {
            envVar = "HC_API_KEY_READONLY";
            inherit (config.age.secrets.healthchecks-api-key-readonly) path;
          }
          {
            envVar = "GOG_KEYRING_PASSWORD";
            value = "gogcli-agenix";
            literal = true;
          }
          {
            envVar = "OPENROUTER_API_KEY";
            inherit (config.age.secrets.openrouter-api-key) path;
          }
          {
            envVar = "AGENTMAIL_API_KEY";
            inherit (config.age.secrets.agentmail-api-key) path;
          }
        ];
        customPlugins = [
          {
            source = "github:edmundmiller/dotfiles/415e35c2e9addcad8c600bcb8ada8ce1a8497077?dir=tools/linear&narHash=sha256-wd7FfzCzZzY0rZrPAAJrYJjMZzenewXfipD4XCc/mH8%3D";
            config.env.LINEAR_API_TOKEN_FILE = linearTokenFile;
          }
        ];
        # Gateway extensions (npm plugins loaded into the gateway process)
        gatewayExtensions = [ pkgs.my.linear-agent-bridge ];
        heartbeatMonitor = {
          enable = true;
          monitors.main = {
            pingUrl = "https://hc-ping.com/71a6388a-9ed5-4edd-b2a9-e5616dec4091";
          };
        };
        webhookProxy.enable = true;
        telegram = {
          enable = true;
          requireMention = false;
          botTokenFile = "/home/emiller/.secrets/telegram-bot-token";
          allowFrom = [
            8357890648 # @edmundamiller
            8748874608 # wife
          ];
          bindings = [
            {
              peerId = "8357890648"; # @edmundamiller
              agentId = "default";
            }
            {
              peerId = "8748874608"; # wife
              agentId = "default";
            }
            {
              peerId = "-5115496901"; # Norbot group
              kind = "group";
              agentId = "default";
            }
          ];
        };
        cronJobs = {
          "Morning brief" = {
            id = "17e31f2c-2a4a-460a-afe4-6317af3163fc";
            schedule = {
              kind = "cron";
              expr = "0 7 * * *";
            };
            model = "openrouter/openai/gpt-5-nano";
            message = ''
              Generate a morning brief for Telegram. Run these commands, then format a bullet-list summary.

              Data gathering:
              1. tnote task list --urgency --no-color --no-pager --limit 8
              2. tnote schedule report today --plain
              3. tnote task list --no-color --no-pager -f "status == 'in-progress'" --limit 5
              4. Check Linear for assigned/high-priority issues:
                 curl -sf -X POST https://api.linear.app/graphql \
                   -H "Authorization: $LINEAR_API_KEY" \
                   -H "Content-Type: application/json" \
                   -d '{"query":"{ issues(filter: { assignee: { isMe: { eq: true } }, state: { type: { nin: [\"canceled\", \"completed\"] } } }, orderBy: priority, first: 5) { nodes { identifier title state { name } priority } } }"}' \
                   | jq -r '.data.issues.nodes[]? | "  \(.identifier) [P\(.priority)] \(.title)"'
              5. Check agentmail inbox:
                 curl -sf -H "Authorization: Bearer $AGENTMAIL_API_KEY" https://api.agentmail.to/v0/inboxes \
                   | jq -r '.inboxes[]? | select(.unread_count > 0) | "\(.address): \(.unread_count) unread"'

              Output format (bullet list, no section headers, keep it tight):
              • Top 3-5 priorities from urgency list
              • Scheduled tasks for today (if any)
              • In-progress work carrying over
              • Linear issues needing attention (if any)
              • Unread mail count (if any)

              Skip sections with no data. Keep total under 15 lines.
            '';
            delivery = {
              mode = "announce";
              to = "8357890648";
            };
          };

          "Daily review" = {
            id = "6bde5748-06f9-4746-987c-4b44afef191b";
            schedule = {
              kind = "cron";
              expr = "0 21 * * *";
            };
            model = "openrouter/openai/gpt-5-nano";
            message = ''
              Generate an end-of-day review for Telegram. Run these commands, then format a bullet-list summary.

              Data gathering:
              1. tnote review daily --batch --no-color --no-pager
              2. tnote time summary --today --by-project --no-color
              3. tnote schedule report tomorrow --plain
              4. Check Linear issues completed today:
                 TODAY=$(date +%Y-%m-%d)
                 curl -sf -X POST https://api.linear.app/graphql \
                   -H "Authorization: $LINEAR_API_KEY" \
                   -H "Content-Type: application/json" \
                   -d '{"query":"{ issues(filter: { completedAt: { gte: \"'"$TODAY"'T00:00:00Z\" }, assignee: { isMe: { eq: true } } }, first: 10) { nodes { identifier title } } }"}' \
                   | jq -r '.data.issues.nodes[]? | "  \(.identifier) \(.title)"'

              Output format (bullet list, no section headers, keep it tight):
              • Tasks completed today
              • Time tracked breakdown (if any logged)
              • Linear issues closed (if any)
              • Tomorrow's scheduled tasks or top priorities
              • Anything still in-progress carrying over

              Skip sections with no data. Keep total under 15 lines.
            '';
            delivery = {
              mode = "announce";
              to = "8357890648";
            };
          };

          "Weekly review" = {
            id = "eabd1501-39bd-4b66-9d1f-842e848b1953";
            schedule = {
              kind = "cron";
              expr = "0 9 * * 5";
            };
            model = "openai-codex/gpt-5.3-codex";
            thinking = "medium";
            message = "Weekly review using tnote: 1) Run 'tnote task list --no-color --no-pager -f status:waiting --limit 20' to find stale waiting tasks, 2) Run 'tnote vault lint --no-color 2>&1 | head -30' to check for data quality issues, 3) Review memory files for outdated entries, 4) Prepare weekend priorities and summarize findings";
            delivery = {
              mode = "announce";
              to = "8357890648";
            };
          };

          "tnote-schedule" = {
            id = "b8804ea5-8033-4639-a9c5-2daa1c222951";
            schedule = {
              kind = "every";
              everyMs = 3600000;
            }; # 1h
            timeoutSeconds = 180;
            message = ''
              Run tnote schedule then commit and push the obsidian vault:

              1. cd /home/emiller/obsidian-vault && tnote schedule run
              2. git add -A
              3. Check if there are changes to commit (git diff --cached --quiet). If no changes, stop here.
              4. git -c commit.gpgsign=false commit -m "sync: tnote schedule run from nuc"
              5. git pull --rebase origin main (NEVER force push)
              6. git push origin main

              Report only if there are errors. If it runs successfully, just confirm briefly.
            '';
          };

          "tnote-update" = {
            id = "39814aea-2c1f-4a5b-9851-e0166a31bbc4";
            schedule = {
              kind = "cron";
              expr = "0 3 * * *";
            };
            timeoutSeconds = 120;
            message = ''
              Update tnote by pulling the latest from the monorepo:

              1. cd /home/emiller/src/personal/tn-monorepo && git pull --rebase origin main

              Report only if there are errors. If it runs successfully, just confirm briefly.
            '';
          };

        };

        sharedSkills = [
          "ast-grep"
          "beads"
          "code-search"
          "healthchecks-io"
          "jut"
          "mdream"
          "pr-review"
          "python-scripts"
          "qmd"
        ];
        skills = [
          {
            name = "agentmail";
            description = "Send and receive emails using AgentMail API. Use when asked to email, check inbox, reply, or manage email.";
            mode = "inline";
            body = ''
              # AgentMail

              Send and receive emails via the AgentMail API. Auth via `$AGENTMAIL_API_KEY` env var.

              ## API Base URL
              ```
              https://api.agentmail.to/v0
              ```

              ## Common Operations

              ```bash
              # List inboxes
              curl -s -H "Authorization: Bearer $AGENTMAIL_API_KEY" \
                https://api.agentmail.to/v0/inboxes

              # Create inbox
              curl -s -X POST -H "Authorization: Bearer $AGENTMAIL_API_KEY" \
                -H "Content-Type: application/json" \
                -d '{"display_name": "My Agent"}' \
                https://api.agentmail.to/v0/inboxes

              # Send email
              curl -s -X POST -H "Authorization: Bearer $AGENTMAIL_API_KEY" \
                -H "Content-Type: application/json" \
                -d '{"to": ["recipient@example.com"], "subject": "Subject", "text": "Body"}' \
                https://api.agentmail.to/v0/inboxes/{inbox_id}/messages/send

              # List messages
              curl -s -H "Authorization: Bearer $AGENTMAIL_API_KEY" \
                https://api.agentmail.to/v0/inboxes/{inbox_id}/messages

              # Reply to message
              curl -s -X POST -H "Authorization: Bearer $AGENTMAIL_API_KEY" \
                -H "Content-Type: application/json" \
                -d '{"text": "Reply body"}' \
                https://api.agentmail.to/v0/inboxes/{inbox_id}/messages/{message_id}/reply
              ```
            '';
          }
          {
            name = "obsidian-vault";
            description = "Search Edmund's Obsidian vault for notes, projects, and knowledge base. Use qmd search, never grep or cat full files.";
            mode = "inline";
            body = ''
              # Obsidian Vault Search (qmd)

              **Always use qmd. Never rg/cat full files** — qmd returns snippets (~500 tokens vs ~15k for full file reads).

              ## Collections
              - `vault` — full vault (PARA: projects, areas, resources, archive)
              - `resources` — reference materials, tools, code snippets
              - `areas` — ongoing areas of responsibility
              - `tasks` — task notes
              - `ai-claude` / `ai-chatgpt` / `ai-chats` — AI conversation history

              ## Commands
              ```bash
              qmd search "topic"              # BM25 full-text (fast, most queries)
              qmd vsearch "concept"           # vector/semantic search
              qmd search "topic" -c resources # scope to collection
              qmd get vault/path/to/note.md   # full file (only if needed)

              # Frontmatter queries (qmd doesn't index YAML frontmatter)
              rg -l "tags:.*bioinformatics" /home/emiller/obsidian-vault
              rg "^status: " /home/emiller/obsidian-vault/01_Projects --include="*.md"
              ```

              ## Workflow
              1. `qmd search` or `qmd vsearch` for content
              2. `rg` only for frontmatter fields (tags, status, dates)
              3. Results include path + snippet — usually enough
              4. Only `qmd get` if you truly need full content
            '';
          }
        ];
      };
      docker.enable = true;
      hass = {
        enable = true;
        postgres.enable = true;
        matter.enable = true;
        zbt2.enable = true;
        homebridge.enable = true;
        homebridge.tailscaleService.enable = true;
        tailscaleService.enable = true;
        customLovelaceModules = with pkgs.home-assistant-custom-lovelace-modules; [
          mushroom # Modern card collection (light, entity, cover, climate, etc.)
          mini-graph-card # Sparkline graphs for sleep vitals
          mini-media-player # Better media player card
          card-mod # CSS customization
        ];
        extraComponents = [
          "homekit_controller" # Discover Apple Home devices (Matter/Thread via Apple TV/HomePod)
          "apple_tv" # Apple TV control + remote
          "roomba" # iRobot Roomba vacuum (config-flow: add via UI after deploy)
          "samsungtv" # Samsung TV integration
          "cast" # Chromecast/Google Cast
          "mobile_app" # HA Companion app (iOS/Android)
          "bluetooth" # BLE device discovery
          "spotify" # Spotify playback control (config-flow: add via UI after deploy)
          "zha" # Zigbee Home Automation via ZBT-2 dongle
          "thread" # Thread border router via ZBT-2 dongle
          "otbr" # OpenThread Border Router (ZBT-2 Thread radio)
          "xiaomi_miio" # Xiaomi air purifier (zhimi.airpurifier.mb3 x2)
          # Devices set up via local token (manual mode, no cloud).
          # Tokens stored at op://Agents/Xiaomi/{couch,bedroom}_purifier_{ip,token,mac,model}
          # Extractor: https://github.com/PiotrMachowski/Xiaomi-cloud-tokens-extractor
        ];
      };
      gatus = {
        enable = true;
        tailscaleService.enable = true;
        alerting.telegram.enable = false;
        alerting.openclaw.enable = false;
        healthcheck = {
          enable = true;
          pingUrl = "https://hc-ping.com/a6bbb4df-b118-4262-9881-9939f3ac7e76";
        };
      };
      homepage = {
        enable = true;
        tailscaleService.enable = true;
        environmentFile = config.age.secrets.homepage-env.path;
        environmentSecrets = [
          {
            envVar = "HOMEPAGE_VAR_HEALTHCHECKS_API_KEY";
            inherit (config.age.secrets.healthchecks-api-key-readonly) path;
          }
        ];
      };
      jellyfin.enable = true;
      lubelogger = {
        enable = true;
        environmentFile = config.age.secrets.lubelogger-env.path;
      };
      speedtest-tracker = {
        enable = true;
        environmentFile = config.age.secrets.speedtest-tracker-env.path;
      };
      prowlarr.enable = true;
      qb.enable = false;
      radarr.enable = true;
      sonarr.enable = true;
      deploy-rs.enable = true;
      mosh.enable = true;
      ssh.enable = true;
      syncthing.enable = false;
      tailscale.enable = true;
      obsidian-sync = {
        enable = true;
        mode = "desktop"; # bidirectional — agents edit vault files on NUC
        op = {
          emailRef = "op://Agents/Obsidian/Email";
          passwordRef = "op://Agents/Obsidian/password";
          itemRef = "op://Agents/Obsidian/Security/one-time password";
          encryptionPasswordRef = "op://Agents/Obsidian/Security/Encryption Password";
          tokenFile = "/etc/opnix-token";
        };
        healthcheck = {
          enable = true;
          pingUrl = "https://hc-ping.com/1be68603-d0da-4a8a-9885-0461985d977f";
        };
      };
      vault-sync = {
        enable = false; # TODO: re-enable after creating cubox-api-key.age and snipd-api-key.age
        # cuboxApiKeyFile = config.age.secrets.cubox-api-key.path;
        # snipdApiKeyFile = config.age.secrets.snipd-api-key.path;
      };
      opencode.enable = true;

      dagster.webserver.port = 3001;

      bugster = {
        enable = true;
        environmentFile = config.age.secrets.bugster-env.path;
        healthcheckPingUrls = {
          github_personal_tasknotes = "https://hc-ping.com/c4b0b3c8-25b4-4cf6-9252-745eaf0a6689";
          linear_personal_tasknotes = "https://hc-ping.com/dc2b60c1-5967-48ea-883d-649ca7ae1bfa";
          travel_time_blocks = "https://hc-ping.com/5b5e8fef-8462-42ff-9562-9fe451972b1c";
        };
        tasknotes = {
          vaultPath = "/home/emiller/obsidian-vault";
          tasksDir = "00_Inbox/Tasks/Bugster";
        };
        sources = [
          {
            type = "github";
            name = "personal";
            tokenEnv = "GITHUB_TOKEN";
            username = "edmundmiller";
            contexts = [ "personal" ];
          }
          {
            type = "linear";
            name = "personal";
            tokenEnv = "LINEAR_TOKEN";
            contexts = [ "personal" ];
          }
        ];

        calendar = {
          enable = true;
          homeAddress = "7859 Clara Dr, Plano, TX 75024";
          sourceCalendars = [
            "primary"
            "monicadd4@gmail.com"
            "family06788939864322602215@group.calendar.google.com"
          ];
        };
      };

      transmission.enable = false;
    };

    # theme.active = "alucard";
  };

  time.timeZone = "America/Chicago";

  boot.kernel.sysctl."net.ipv4.ip_forward" = 1;

  # FIXME https://discourse.nixos.org/t/logrotate-config-fails-due-to-missing-group-30000/28501/7
  services.logrotate.checkConfig = false;

  users.users.emiller.hashedPasswordFile = config.age.secrets.emiller_password.path;

  # opnix: 1Password service account token bootstrapped at /etc/opnix-token
  # Bootstrap (one-time): op read "op://Private/xkq3yij62kltcldkmk7qgkq66a/credential" \
  #   | ssh nuc "sudo tee /etc/opnix-token && sudo chmod 640 /etc/opnix-token"
  # The token file is read directly by obsidian-sync (and any future op CLI consumers).
  # services.onepassword-secrets.enable left false until a non-Private vault secret is needed.

  age.secrets.lubelogger-env.owner = "lubelogger";
  age.secrets.bugster-env.owner = "emiller";
  age.secrets.speedtest-tracker-env.owner = "root";
  age.secrets.linear-refresh-token.owner = "emiller";

  # Bootstrap the linear token state file from agenix so openclawPluginGuard
  # doesn't fail during home-manager activation (before linear-token-init.service runs).
  system.activationScripts.bootstrapLinearToken = {
    text = ''
      TOKEN_FILE="/home/emiller/.local/state/openclaw-linear/token"
      if [ ! -s "$TOKEN_FILE" ]; then
        mkdir -p "$(dirname "$TOKEN_FILE")"
        cp /run/agenix/linear-api-token "$TOKEN_FILE"
        chmod 600 "$TOKEN_FILE"
        chown -R emiller:users "$(dirname "$TOKEN_FILE")"
      fi
    '';
    deps = [
      "agenixInstall"
      "agenixChown"
    ];
  };

  # systemd.services.znapzend.serviceConfig.User = lib.mkForce "emiller";
  services.znapzend = {
    # FIXME
    enable = false;
    autoCreation = true;
    zetup = {
      "tank/user/home" = {
        plan = "1d=>1h,1m=>1d,1y=>1m";
        recursive = true;
        destinations.local = {
          dataset = "datatank/backup/unas";
          presend = "${pkgs.curl}/bin/curl -m 10 --retry 5 https://hc-ping.com/ccb26fbc-95af-45bb-b4e6-38da23db6893/start";
          postsend = "${pkgs.curl}/bin/curl -m 10 --retry 5 https://hc-ping.com/ccb26fbc-95af-45bb-b4e6-38da23db6893";
        };
      };
    };
  };
}
