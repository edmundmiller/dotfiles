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
    REFRESH_TOKEN=$(cat /run/agenix/linear-refresh-token)
    CLIENT_ID="c64c969674a02fccc863d4aa950ec132"
    CLIENT_SECRET="72406896af1a83cb5765c6042a59cde2"

    RESPONSE=$(${pkgs.curl}/bin/curl -sf -X POST https://api.linear.app/oauth/token \
      -H "Content-Type: application/x-www-form-urlencoded" \
      --data-urlencode "grant_type=refresh_token" \
      --data-urlencode "client_id=$CLIENT_ID" \
      --data-urlencode "client_secret=$CLIENT_SECRET" \
      --data-urlencode "refresh_token=$REFRESH_TOKEN")

    ACCESS_TOKEN=$(echo "$RESPONSE" | ${pkgs.jq}/bin/jq -r '.access_token')
    if [ "$ACCESS_TOKEN" = "null" ] || [ -z "$ACCESS_TOKEN" ]; then
      echo "Failed to refresh Linear token: $RESPONSE" >&2
      exit 1
    fi

    echo -n "$ACCESS_TOKEN" > "''${STATE_DIRECTORY}/token"
    echo "Linear OAuth token refreshed"
  '';

  linear-agent-bridge = pkgs.buildNpmPackage rec {
    pname = "linear-agent-bridge";
    version = "0.1.3";
    src = pkgs.fetchFromGitHub {
      owner = "edmundmiller";
      repo = "linear-agent-bridge";
      rev = "39742e0fd873734e8bfb75a6add5d23b0542557e";
      hash = "sha256-I7D+uT2ZoUeYfoZU/R7ImUZKku2YYTBy3ki7DHfiRMc=";
    };
    npmDepsHash = "sha256-UPm3S6F9KKok1rpQbz0mYsC07YeHtFTBnAUip2k6Moc=";
    buildPhase = "npm run build";
    installPhase = ''
      mkdir -p $out/lib/linear-agent-bridge
      cp -r dist openclaw.plugin.json package.json $out/lib/linear-agent-bridge/
    '';
    meta.description = "OpenClaw plugin: Linear → multi-agent workspace";
  };
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
        claudeMaxProxy.enable = true;
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
        ];
        customPlugins = [
          {
            source = "github:edmundmiller/dotfiles/415e35c2e9addcad8c600bcb8ada8ce1a8497077?dir=tools/linear&narHash=sha256-wd7FfzCzZzY0rZrPAAJrYJjMZzenewXfipD4XCc/mH8%3D";
            config.env.LINEAR_API_TOKEN_FILE = linearTokenFile;
          }
        ];
        # Gateway extensions (npm plugins loaded into the gateway process)
        gatewayExtensions = [ linear-agent-bridge ];
        heartbeatMonitor = {
          enable = true;
          monitors.main = {
            agent = "main";
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
        sharedSkills = [
          "ast-grep"
          "beads"
          "code-search"
          "healthchecks-io"
          "jut"
          "mdream"
          "pr-review"
          "python-scripts"
        ];
        skills = [
          {
            name = "obsidian-vault";
            description = "Access Edmund's Obsidian vault for notes, projects, and knowledge base";
            mode = "inline";
            body = ''
              # Obsidian Vault Access

              Location: `/home/emiller/obsidian-vault`

              ## Structure (PARA method)
              - `00_Inbox/` - New notes, quick captures
              - `01_Projects/` - Active projects with tasks
              - `02_Areas/` - Ongoing areas of responsibility
              - `03_Resources/` - Reference material, topics of interest
              - `04_Archive/` - Completed/inactive items
              - `05_Attachments/` - Images, PDFs, files
              - `06_Metadata/` - Templates, config

              ## How to Search
              ```bash
              rg "search term" /home/emiller/obsidian-vault
              rg -l "search term" /home/emiller/obsidian-vault  # list files only
              ```

              ## How to Read/List
              ```bash
              cat "/home/emiller/obsidian-vault/path/to/note.md"
              ls /home/emiller/obsidian-vault/01_Projects/
              ```
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
      ssh.enable = true;
      syncthing.enable = false;
      tailscale.enable = true;
      obsidian-sync.enable = true;
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

  age.secrets.lubelogger-env.owner = "lubelogger";
  age.secrets.bugster-env.owner = "dagster";
  age.secrets.speedtest-tracker-env.owner = "root";
  age.secrets.linear-refresh-token.owner = "emiller";

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
