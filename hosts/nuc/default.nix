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
  qmd = pkgs.writeShellScriptBin "qmd" ''
    export NODE_LLAMA_CPP_GPU=off
    exec ${pkgs.llm-agents.qmd}/bin/qmd "$@"
  '';

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

  # Allow __noChroot derivations for occasional upstream packages that still
  # assume networked builds.
  nix.settings.sandbox = "relaxed";

  # nix-ld for dynamically linked binaries (e.g. sag TTS)
  programs.nix-ld = {
    enable = true;
    libraries = with pkgs; [
      alsa-lib # libasound.so.2 for sag audio playback
    ];
  };

  # qmd skill: NUC-only (not in global agent-skills bundle to avoid token waste on Mac)
  home.file.".openclaw/workspace/skills/qmd".source =
    "${inputs.skills-catalog.inputs.qmd-repo}/skills/qmd";

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

    # Keep qmd as primary memory backend, but use a thin local wrapper around
    # llm-agents.nix qmd that forces CPU mode on this NUC, plus query mode.
    programs.openclaw.config.memory.qmd = {
      command = pkgs.lib.mkForce "${qmd}/bin/qmd";
      searchMode = pkgs.lib.mkForce "query";
    };

    # Force memory embeddings to Gemini to avoid OpenAI embed spend.
    programs.openclaw.config.agents.defaults.memorySearch = {
      provider = "gemini";
      model = "gemini-embedding-2-preview";
      outputDimensionality = 3072;
      fallback = "none";
    };

    # Required for HA OpenClaw integration (OpenAI-compatible endpoint)
    programs.openclaw.config.gateway.http.endpoints.chatCompletions.enabled = true;

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
    qmd # thin wrapper around llm-agents.nix qmd forcing CPU mode on this NUC
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
      audiobookshelf = {
        enable = true;
        tailscaleService.enable = true;
      };
      # OpenClaw — agents, secrets, cron jobs, and skills are workspace-owned
      # (defined in openclaw-workspace module). Only infra config stays here.
      openclaw = {
        enable = true;
        gatewayTokenFile = config.age.secrets.openclaw-gateway-token.path;
        hooksTokenFile = config.age.secrets.openclaw-hooks-token.path;
        secrets = [
          {
            envVar = "GEMINI_API_KEY";
            inherit (config.age.secrets.gemini-api-key) path;
          }
        ];
        customPlugins = [
          {
            source = "github:edmundmiller/dotfiles/415e35c2e9addcad8c600bcb8ada8ce1a8497077?dir=tools/linear&narHash=sha256-wd7FfzCzZzY0rZrPAAJrYJjMZzenewXfipD4XCc/mH8%3D";
            config.env.LINEAR_API_TOKEN_FILE = linearTokenFile;
          }
        ];
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
            1087968824 # Telegram anonymous admin sender id
          ];
          bindings = [
            {
              peerId = "8357890648"; # @edmundamiller
              agentId = "edmund";
            }
            {
              peerId = "8748874608"; # wife
              agentId = "monica";
            }
            {
              peerId = "-5115496901"; # Norbot group
              kind = "group";
              agentId = "family";
            }
            {
              peerId = "-1003862456724"; # Norbot supergroup base id (topic allowlist gate)
              kind = "group";
              agentId = "family";
            }
            {
              peerId = "-1003862456724:topic:1"; # General
              kind = "group";
              agentId = "family";
            }
            {
              peerId = "-1003862456724:topic:23"; # Dev
              kind = "group";
              agentId = "dev";
            }
            {
              peerId = "-1003862456724:topic:24"; # Commander Bun Bun
              kind = "group";
              agentId = "commanderbunbun";
            }
            {
              peerId = "-1003862456724:topic:25"; # Scheduler
              kind = "group";
              agentId = "scheduler";
            }
            {
              peerId = "-1003862456724:topic:26"; # Monica
              kind = "group";
              agentId = "monica";
            }
            {
              peerId = "-1003862456724:topic:27"; # Finn
              kind = "group";
              agentId = "finn";
            }
          ];
        };
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
          "homekit" # Expose HA entities to Apple Home/Siri (HomePods)
          "homekit_controller" # Discover Apple Home devices (Matter/Thread via Apple TV/HomePod)
          "apple_tv" # Apple TV control + remote
          "roomba" # iRobot Roomba vacuum (config-flow: add via UI after deploy)
          "samsungtv" # Samsung TV integration
          "cast" # Chromecast/Google Cast
          "mobile_app" # HA Companion app (iOS/Android)
          "bluetooth" # BLE device discovery
          "spotify" # Spotify playback control (config-flow: add via UI after deploy)
          "elevenlabs" # ElevenLabs TTS/STT (config-flow: add API key via UI)
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
      jellyfin = {
        enable = true;
        tailscaleService.enable = true;
      };
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

      open-wearables = {
        enable = true;
        # API only for now (historical Apple XML import + agent access)
        enableFrontend = false;
      };

      dagster.webserver.port = 3001;

      finances-dagster = {
        enable = true;
        opTokenFile = "/etc/opnix-token";
        dailyHealthcheckPingUrl = "https://hc-ping.com/465b4f6c-8107-487e-bfd7-dc5e30168f32";
      };

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
