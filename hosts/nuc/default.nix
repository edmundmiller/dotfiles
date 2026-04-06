# Go nuc yourself (2026-02-26)
{
  config,
  inputs,
  lib,
  options,
  pkgs,
  ...
}:
let
  hostSystem = pkgs.stdenv.hostPlatform.system;
  hermesAgentBase = inputs.hermesAgent.packages.${hostSystem}.default;
  anneHermesLauncher = inputs.openclaw-workspace.packages.${hostSystem}.anne-hermes;
  hermesAgentPatched = pkgs.stdenvNoCC.mkDerivation {
    pname = "hermes-agent";
    version = "0.1.0-fallback-endpoint-patched";
    dontUnpack = true;
    nativeBuildInputs = [ pkgs.python3 ];
    installPhase = ''
      runHook preInstall

      cp -a ${hermesAgentBase} "$out"
      chmod -R u+w "$out"

      base_venv="$(grep '^exec ' ${hermesAgentBase}/bin/hermes | cut -d '"' -f 2 | sed 's|/bin/hermes$||')"
      if [ -z "$base_venv" ]; then
        echo "Failed to locate hermes-agent-env from ${hermesAgentBase}/bin/hermes" >&2
        exit 1
      fi

      original_run_agent="$(find "$base_venv/lib" -path '*/site-packages/run_agent.py' | head -1)"
      if [ -z "$original_run_agent" ]; then
        echo "Failed to locate run_agent.py in $base_venv" >&2
        exit 1
      fi

      mkdir -p "$out/lib/hermes-overlay"
      cp "$original_run_agent" "$out/lib/hermes-overlay/run_agent.py"
      chmod u+w "$out/lib/hermes-overlay/run_agent.py"

      export HERMES_OVERLAY="$out/lib/hermes-overlay"
      export RUN_AGENT_PATH="$out/lib/hermes-overlay/run_agent.py"
      ${pkgs.python3}/bin/python - <<'PY'
      import os
      from pathlib import Path

      path = Path(os.environ["RUN_AGENT_PATH"])
      text = path.read_text()
      old = """        # Use centralized router for client construction.\n        # raw_codex=True because the main agent needs direct responses.stream()\n        # access for Codex providers.\n        try:\n            from agent.auxiliary_client import resolve_provider_client\n            fb_client, _ = resolve_provider_client(\n                fb_provider, model=fb_model, raw_codex=True)\n"""
      new = """        # Use centralized router for client construction.\n        # raw_codex=True because the main agent needs direct responses.stream()\n        # access for Codex providers.\n        fb_base_url = (fb.get(\"base_url\") or \"\").strip() or None\n        fb_api_key_env = (fb.get(\"api_key_env\") or \"\").strip()\n        fb_explicit_key = None\n        if fb_api_key_env:\n            fb_explicit_key = os.getenv(fb_api_key_env, \"\").strip() or None\n        try:\n            from agent.auxiliary_client import resolve_provider_client\n            fb_client, _ = resolve_provider_client(\n                fb_provider,\n                model=fb_model,\n                raw_codex=True,\n                explicit_base_url=fb_base_url,\n                explicit_api_key=fb_explicit_key,\n            )\n"""
      if old not in text:
          raise SystemExit(f"expected fallback snippet not found in {path}")
      path.write_text(text.replace(old, new, 1))
      PY

      for exe in "$out/bin/hermes" "$out/bin/hermes-agent" "$out/bin/hermes-acp"; do
        export WRAPPER_PATH="$exe"
        ${pkgs.python3}/bin/python - <<'PY'
      import os
      from pathlib import Path

      path = Path(os.environ["WRAPPER_PATH"])
      text = path.read_text()
      needle = 'exec "'
      replacement = (
          f"export PYTHONPATH='{os.environ['HERMES_OVERLAY']}':$PYTHONPATH\n"
          'exec "'
      )
      if needle not in text:
          raise SystemExit(f"expected exec line not found in {path}")
      path.write_text(text.replace(needle, replacement, 1))
      PY
        substituteInPlace "$exe" --replace-fail ${hermesAgentBase} "$out"
      done

      runHook postInstall
    '';
    inherit (hermesAgentBase) meta;
  };
  discordBindings = import (inputs.openclaw-workspace + /deployments/nuc/discord-bindings.nix) {
    inherit lib;
  };
  anneDiscordBindings = (discordBindings.agents or { }).anne or { };
  anneHermesGateway = pkgs.writeShellScript "hermes-anne-discord-gateway" ''
    export PATH=${
      lib.escapeShellArg (
        lib.makeBinPath [
          anneHermesLauncher
          hermesAgentPatched
          pkgs.bashInteractive
          pkgs.coreutils
          pkgs.findutils
          pkgs.git
          pkgs.python3
        ]
      )
    }:$PATH
    exec ${anneHermesLauncher}/bin/anne-hermes gateway
  '';
  # Telegram routing topology for this host:
  # - "hermes" => current/live mode; Hermes owns all Telegram on the current bot token
  # - "split"  => prepared future split; the shared bot keeps family/group traffic,
  #                while Hermes owns Scintillate DM on a dedicated Telegram bot token
  telegramRoutingMode = "hermes";
  telegramOwnedByHermes = telegramRoutingMode == "hermes";
  telegramSplitMode = telegramRoutingMode == "split";

  # Binding runtime controls whether the shared Telegram bindings keep the
  # Scintillate DM binding. Leave this at "hermes" for both current mode and
  # split mode so family/group routing stays separate while Hermes owns
  # Scintillate DM.
  telegramBindingRuntime = "hermes";
  hermesTelegramEnable = telegramOwnedByHermes || telegramSplitMode;
  telegramBindingsModule =
    let
      telegramBindingsPath = inputs.openclaw-workspace + /deployments/nuc/telegram-bindings.nix;
    in
    import telegramBindingsPath;
  telegramBindings = telegramBindingsModule (
    {
      inherit lib;
    }
    //
      lib.optionalAttrs
        (builtins.hasAttr "agentGatewayRuntime" (builtins.functionArgs telegramBindingsModule))
        {
          agentGatewayRuntime = telegramBindingRuntime;
        }
    //
      lib.optionalAttrs
        (
          !(builtins.hasAttr "agentGatewayRuntime" (builtins.functionArgs telegramBindingsModule))
          && builtins.hasAttr "telegramRuntime" (builtins.functionArgs telegramBindingsModule)
        )
        {
          telegramRuntime = telegramBindingRuntime;
        }
  );
  hermesScintillateChannelIds = lib.sort lib.versionOlder (
    builtins.filter (peerId: telegramBindings.direct.${peerId}.agentId == "scintillate") (
      builtins.attrNames telegramBindings.direct
    )
  );
  hermesScintillateHomeChannel = builtins.head hermesScintillateChannelIds;
  hermesScintillateAllowedUserIds =
    if telegramSplitMode then hermesScintillateChannelIds else map toString telegramBindings.allowFrom;
  hermesScintillateAllowedUsers = lib.concatStringsSep "," hermesScintillateAllowedUserIds;
  # In split mode, Hermes needs its own Telegram bot token so it can own only
  # the Scintillate DM without competing with the shared family/group bot.
  hermesScintillateTelegramBotTokenFile =
    if telegramSplitMode then
      config.age.secrets.telegram-bot-token-scintillate.path
    else
      config.age.secrets.telegram-bot-token.path;
  linearTokenFile = "/home/emiller/.local/state/hermes-linear/token";
  mkAgentSecret = envVar: secretName: {
    inherit envVar;
    inherit (config.age.secrets.${secretName}) path;
  };
  hermesProviderSecrets = [
    (mkAgentSecret "AGENTMAIL_API_KEY" "agentmail-api-key")
    (mkAgentSecret "ANTHROPIC_API_KEY" "anthropic-api-key")
    (mkAgentSecret "GEMINI_API_KEY" "gemini-api-key")
    (mkAgentSecret "FIREWORKS_API_KEY" "fireworks-api-key")
    (mkAgentSecret "HA_TOKEN" "ha-hermes-token")
    (mkAgentSecret "HASS_TOKEN" "ha-hermes-token")
    (mkAgentSecret "KILOCODE_API_KEY" "kilocode-api-key")
    (mkAgentSecret "OPENAI_API_KEY" "openai-api-key")
    (mkAgentSecret "OPENROUTER_API_KEY" "openrouter-api-key")
    (mkAgentSecret "PERPLEXITY_API_KEY" "perplexity-api-key")
  ];
  hermesScintillateSecrets = hermesProviderSecrets ++ [
    {
      envVar = "TELEGRAM_BOT_TOKEN";
      path = hermesScintillateTelegramBotTokenFile;
    }
    {
      envVar = "LINEAR_API_KEY";
      path = linearTokenFile;
    }
  ];
  hermesAnneSecrets = hermesProviderSecrets ++ [
    {
      envVar = "DISCORD_BOT_TOKEN";
      inherit (config.age.secrets.discord-bot-token-anne) path;
    }
  ];
  obsidianOpRefs = {
    emailRef = "op://Agents/Obsidian/Email";
    passwordRef = "op://Agents/Obsidian/password";
    itemRef = "op://Agents/Obsidian/Security/one-time password";
    encryptionPasswordRef = "op://Agents/Obsidian/Security/Encryption Password";
    tokenFile = "/etc/opnix-token";
  };
  millDocsVaultPath = "/home/emiller/mill-docs";
  legacyMillDocsPath = "/home/emiller/sync/mill-docs";
  millDocsDeviceName = "nuc-mill-docs";
  obsidianExcludedFolders = ".git,.beads,.claude,.github,.scripts,.opencode,.pi,.qmd,.tn,.config,.agents,.goose,.hooks,.pytest_cache,node_modules,TaskNotes,OLD_VAULT";
  ob = "${pkgs.my.obsidian-headless}/bin/ob";
  op = "${pkgs._1password-cli}/bin/op";
  qmd = pkgs.writeShellScriptBin "qmd" ''
    export NODE_LLAMA_CPP_GPU=off
    exec ${pkgs.llm-agents.qmd}/bin/qmd "$@"
  '';

  millDocsObsidianLoginScript = pkgs.writeShellScript "obsidian-sync-mill-docs-login" ''
    set -euo pipefail
    if ${ob} login 2>&1 | grep -q "Logged in"; then
      echo "Using existing Obsidian Sync session from obsidian-sync.service"
      exit 0
    fi
    echo "Obsidian Sync session not ready yet; start obsidian-sync.service first." >&2
    exit 1
  '';

  millDocsObsidianSetupScript = pkgs.writeShellScript "obsidian-sync-mill-docs-setup" ''
    set -euo pipefail
    if ${ob} sync-list-local 2>/dev/null | grep -q '${millDocsVaultPath}'; then
      echo "mill-docs vault already configured"
      exit 0
    fi
    mkdir -p '${millDocsVaultPath}'
    echo "Running sync-setup for mill-docs..."
    ${ob} sync-setup \
      --vault 'mill-docs' \
      --path '${millDocsVaultPath}' \
      --password "$(${op} read '${obsidianOpRefs.encryptionPasswordRef}')" \
      --device-name '${millDocsDeviceName}'
  '';

  millDocsObsidianConfigScript = pkgs.writeShellScript "obsidian-sync-mill-docs-config" ''
    set -euo pipefail
    ${ob} sync-config \
      --path '${millDocsVaultPath}' \
      --mode bidirectional \
      --device-name '${millDocsDeviceName}' \
      --excluded-folders '${obsidianExcludedFolders}'
  '';

  millDocsObsidianSyncScript = pkgs.writeShellScript "obsidian-sync-mill-docs-start" ''
    set -euo pipefail
    rm -rf '${millDocsVaultPath}/.obsidian/.sync.lock'
    exec ${ob} sync --path '${millDocsVaultPath}' --continuous
  '';

in
{
  inherit (telegramBindings) assertions;

  system.activationScripts = {

    removeLegacyZele = ''
      rm -f /home/emiller/.bun/bin/zele /home/emiller/.cache/npm/bin/zele
    '';

    relocateMillDocsVault = {
      text = ''
        LEGACY_PATH="${legacyMillDocsPath}"
        TARGET_PATH="${millDocsVaultPath}"
        mkdir -p /home/emiller /home/emiller/sync

        if [ -d "$LEGACY_PATH" ] && [ ! -L "$LEGACY_PATH" ] && [ ! -e "$TARGET_PATH" ]; then
          mv "$LEGACY_PATH" "$TARGET_PATH"
        fi

        if [ -e "$TARGET_PATH" ]; then
          if [ -e "$LEGACY_PATH" ] || [ -L "$LEGACY_PATH" ]; then
            if [ ! -L "$LEGACY_PATH" ] || [ "$(readlink -f "$LEGACY_PATH")" != "$TARGET_PATH" ]; then
              rm -rf "$LEGACY_PATH"
            fi
          fi
          ln -sfn "$TARGET_PATH" "$LEGACY_PATH"
          chown -h emiller:users "$LEGACY_PATH"
          chown -R emiller:users "$TARGET_PATH"
        fi
      '';
    };

    bootstrapLinearToken = {
      text = ''
        TOKEN_FILE="/home/emiller/.local/state/hermes-linear/token"
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

    hermesScintillateSecrets = {
      deps = [
        "agenixInstall"
        "agenixChown"
        "canonical-hermes-scintillate-materialize"
      ];
      text = ''
        ENV_DIR="/run/hermes-scintillate-env"
        ENV_FILE="$ENV_DIR/secrets.env"
        HERMES_ENV_HOME="/var/lib/hermes-scintillate/.hermes"
        HERMES_ENV_FILE="$HERMES_ENV_HOME/.env"
        TMP_HERMES_ENV="$(mktemp)"
        trap 'rm -f "$TMP_HERMES_ENV"' EXIT

        mkdir -p "$ENV_DIR"
        install -d -o emiller -g users -m 0750 "$HERMES_ENV_HOME"
        : > "$ENV_FILE"
        chmod 600 "$ENV_FILE"

        if [ -f "$HERMES_ENV_FILE" ]; then
          cp "$HERMES_ENV_FILE" "$TMP_HERMES_ENV"
        else
          : > "$TMP_HERMES_ENV"
        fi

        ${lib.concatMapStringsSep "\n" (secret: ''
                    ${pkgs.python3}/bin/python - "$TMP_HERMES_ENV" ${lib.escapeShellArg secret.envVar} <<'PY'
          import sys
          from pathlib import Path

          path = Path(sys.argv[1])
          env_var = sys.argv[2]
          lines = path.read_text().splitlines() if path.exists() else []
          path.write_text("\n".join(line for line in lines if not line.startswith(f"{env_var}=")) + ("\n" if lines else ""))
          PY
                    if [ -f ${lib.escapeShellArg (toString secret.path)} ]; then
                      secret_value="$(cat ${lib.escapeShellArg (toString secret.path)})"
                      printf '%s=%s\n' ${lib.escapeShellArg secret.envVar} "$secret_value" >> "$ENV_FILE"
                      printf '%s=%s\n' ${lib.escapeShellArg secret.envVar} "$secret_value" >> "$TMP_HERMES_ENV"
                    fi
        '') hermesScintillateSecrets}

        install -m 600 -o emiller -g users "$TMP_HERMES_ENV" "$HERMES_ENV_FILE"
      '';
    };

    hermesAnneSecrets = {
      deps = [
        "agenixInstall"
        "agenixChown"
      ];
      text = ''
        ANNE_STATE_DIR="/var/lib/hermes-anne"
        ENV_DIR="/run/hermes-anne-env"
        ENV_FILE="$ENV_DIR/secrets.env"
        HERMES_ENV_HOME="$ANNE_STATE_DIR/.hermes"
        HERMES_ENV_FILE="$HERMES_ENV_HOME/.env"
        TMP_HERMES_ENV="$(mktemp)"
        trap 'rm -f "$TMP_HERMES_ENV"' EXIT

        install -d -o emiller -g users -m 0750 \
          "$ANNE_STATE_DIR" \
          "$ANNE_STATE_DIR/.local" \
          "$ANNE_STATE_DIR/.local/state" \
          "$ANNE_STATE_DIR/.local/state/hermes" \
          "$ANNE_STATE_DIR/.local/state/hermes/gateway-locks" \
          "$HERMES_ENV_HOME" \
          "$HERMES_ENV_HOME/workspace" \
          "$HERMES_ENV_HOME/workspace/repos"

        ln -sfn ${millDocsVaultPath} "$HERMES_ENV_HOME/workspace/repos/mill-docs"
        chown -h emiller:users "$HERMES_ENV_HOME/workspace/repos/mill-docs"

        mkdir -p "$ENV_DIR"
        : > "$ENV_FILE"
        chmod 600 "$ENV_FILE"
        chown emiller:users "$ENV_FILE"

        if [ -f "$HERMES_ENV_FILE" ]; then
          cp "$HERMES_ENV_FILE" "$TMP_HERMES_ENV"
        else
          : > "$TMP_HERMES_ENV"
        fi

        ${lib.concatMapStringsSep "\n" (secret: ''
                    ${pkgs.python3}/bin/python - "$TMP_HERMES_ENV" ${lib.escapeShellArg secret.envVar} <<'PY'
          import sys
          from pathlib import Path

          path = Path(sys.argv[1])
          env_var = sys.argv[2]
          lines = path.read_text().splitlines() if path.exists() else []
          path.write_text("\n".join(line for line in lines if not line.startswith(f"{env_var}=")) + ("\n" if lines else ""))
          PY
                    if [ -f ${lib.escapeShellArg (toString secret.path)} ]; then
                      secret_value="$(cat ${lib.escapeShellArg (toString secret.path)})"
                      printf '%s=%s\n' ${lib.escapeShellArg secret.envVar} "$secret_value" >> "$ENV_FILE"
                      printf '%s=%s\n' ${lib.escapeShellArg secret.envVar} "$secret_value" >> "$TMP_HERMES_ENV"
                    fi
        '') hermesAnneSecrets}

        ${lib.optionalString (anneDiscordBindings ? requireMention) ''
          printf 'DISCORD_REQUIRE_MENTION=%s\n' ${
            lib.escapeShellArg (if anneDiscordBindings.requireMention then "true" else "false")
          } >> "$ENV_FILE"
        ''}
        ${lib.optionalString ((anneDiscordBindings.freeResponseChannelIds or [ ]) != [ ]) ''
          printf 'DISCORD_FREE_RESPONSE_CHANNELS=%s\n' ${lib.escapeShellArg (lib.concatStringsSep "," (map toString anneDiscordBindings.freeResponseChannelIds))} >> "$ENV_FILE"
        ''}
        ${lib.optionalString ((anneDiscordBindings.homeChannelId or null) != null) ''
          printf 'DISCORD_HOME_CHANNEL=%s\n' ${lib.escapeShellArg (toString anneDiscordBindings.homeChannelId)} >> "$ENV_FILE"
        ''}
        ${lib.optionalString ((anneDiscordBindings.homeChannelName or null) != null) ''
          printf 'DISCORD_HOME_CHANNEL_NAME=%s\n' ${lib.escapeShellArg anneDiscordBindings.homeChannelName} >> "$ENV_FILE"
        ''}
        ${lib.optionalString (anneDiscordBindings.allowAllUsers or false) ''
          printf 'DISCORD_ALLOW_ALL_USERS=true\n' >> "$ENV_FILE"
          printf 'GATEWAY_ALLOW_ALL_USERS=true\n' >> "$ENV_FILE"
        ''}

        install -m 600 -o emiller -g users "$TMP_HERMES_ENV" "$HERMES_ENV_FILE"
      '';
    };

    hermesScintillateTaskNotesCompat = {
      deps = [ "canonical-hermes-scintillate-materialize" ];
      text = ''
        HERMES_HOME_BASE="/var/lib/hermes-scintillate"

        install -d -o emiller -g users -m 0750 "$HERMES_HOME_BASE/.local/bin"
        install -d -o emiller -g users -m 0750 "$HERMES_HOME_BASE/src/personal"

        ln -sfn /home/emiller/.local/bin/tnote "$HERMES_HOME_BASE/.local/bin/tnote"
        ln -sfn /home/emiller/src/personal/tn-monorepo "$HERMES_HOME_BASE/src/personal/tn-monorepo"
        ln -sfn /home/emiller/obsidian-vault "$HERMES_HOME_BASE/obsidian-vault"

        chown -h emiller:users "$HERMES_HOME_BASE/.local/bin/tnote"
        chown -h emiller:users "$HERMES_HOME_BASE/src/personal/tn-monorepo"
        chown -h emiller:users "$HERMES_HOME_BASE/obsidian-vault"
      '';
    };

    disableLegacyHermesScintillateGateway = {
      text = ''
        LEGACY_UNIT="/home/emiller/.config/systemd/user/hermes-gateway-scintillate.service"

        if [ -e "$LEGACY_UNIT" ]; then
          rm -f "$LEGACY_UNIT"
        fi

        USER_UID="$(${pkgs.coreutils}/bin/id -u emiller)"
        export XDG_RUNTIME_DIR="/run/user/$USER_UID"
        if [ -S "$XDG_RUNTIME_DIR/bus" ]; then
          ${pkgs.util-linux}/bin/runuser -u emiller -- \
            ${pkgs.systemd}/bin/systemctl --user disable --now hermes-gateway-scintillate.service || true
          ${pkgs.util-linux}/bin/runuser -u emiller -- \
            ${pkgs.systemd}/bin/systemctl --user reset-failed hermes-gateway-scintillate.service || true
          ${pkgs.util-linux}/bin/runuser -u emiller -- \
            ${pkgs.systemd}/bin/systemctl --user daemon-reload || true
        else
          ${pkgs.procps}/bin/pkill -u emiller -f 'hermes_cli.main gateway run --replace' || true
        fi
      '';
      deps = [ "users" ];
    };
  };

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
  home-manager.users.${config.user.name} = {
    # Disable dconf on headless server - no dbus session available
    dconf.enable = false;
  };

  environment.systemPackages = with pkgs; [
    taskwarrior3
    sqlite
    jq # For agent skills that parse JSON (e.g. homeassistant)
    chromium # Browser automation runtime
    nodejs # Agent/plugin runtime support
    python3 # For node-gyp (pi-interactive-shell/node-pty)
    gcc
    gnumake # For node-gyp native compilation
    cmake # For node-llama-cpp (qmd dependency)
    claude-code # CLI backend for local agents
    codex # CLI backend for local agents
    bun # For pi CLI backend (npm: @mariozechner/pi-coding-agent)
    uv # For vault sync scripts (PEP 723 inline deps)
    home-assistant-cli # hass-cli: agent-friendly HA REST API wrapper
    inputs.nix-steipete-tools.packages.${hostSystem}.sag # TTS runtime support
    qmd # thin wrapper around llm-agents.nix qmd forcing CPU mode on this NUC
    my.zele # packaged upstream+patches zele CLI
  ];
  imports = [
    ../_server.nix
    ../_home.nix
    ./hardware-configuration.nix
    ./disko.nix
    ./backups.nix
  ];

  services.hermes-agent = {
    package = hermesAgentPatched;
    user = "emiller";
    group = "users";
    createUser = false;
    environment = {
      HA_URL = "http://192.168.1.222:8123";
      HASS_URL = "http://192.168.1.222:8123";
    }
    // lib.optionalAttrs hermesTelegramEnable {
      TELEGRAM_ALLOWED_USERS = hermesScintillateAllowedUsers;
      TELEGRAM_HOME_CHANNEL = hermesScintillateHomeChannel;
    };
    environmentFiles = [ "/run/hermes-scintillate-env/secrets.env" ];
  };

  systemd.services.hermes-agent-anne = {
    description = "Hermes Agent Gateway (anne on Discord)";
    wantedBy = [ "multi-user.target" ];
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    serviceConfig = {
      Type = "simple";
      User = "emiller";
      Group = "users";
      WorkingDirectory = "/var/lib/hermes-anne";
      Environment = [
        "HERMES_HOME=/var/lib/hermes-anne/.hermes"
        "HERMES_MANAGED=true"
        "HOME=/var/lib/hermes-anne"
        "MESSAGING_CWD=/var/lib/hermes-anne/.hermes/workspace"
      ];
      EnvironmentFile = [ "/run/hermes-anne-env/secrets.env" ];
      ExecStart = lib.mkForce anneHermesGateway;
      Restart = "always";
      RestartSec = 5;
      NoNewPrivileges = true;
      PrivateTmp = true;
      ProtectHome = false;
      ProtectSystem = "strict";
      ReadWritePaths = [ "/var/lib/hermes-anne" ];
    };
  };

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
    }
    // lib.optionalAttrs (lib.hasAttrByPath [ "modules" "services" "hermes" ] options) {
      hermes = {
        # Scintillate stays on Hermes even when Telegram ingress eventually
        # splits between OpenClaw (family/group) and Hermes (Scintillate DM).
        enable = true;
        agentId = "scintillate";
        workspaceLinks."repos/obsidian-vault" = "/home/emiller/obsidian-vault";
        workspaceLinks."repos/tnote" = "/home/emiller/src/personal/tn-monorepo";
      };
    }
    // {
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
        op = obsidianOpRefs;
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
          snipd_personal_contentnotes = "https://hc-ping.com/c5a1738e-d12b-46e4-bcd9-b0c8f1fa80e7";
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
          {
            type = "snipd";
            name = "personal";
            tokenEnv = "SNIPD_API_KEY";
            contexts = [ "podcasts" ];
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
  systemd = {
    tmpfiles.rules = [
      "d ${millDocsVaultPath} 0755 emiller users -"
    ];

    services.obsidian-sync-mill-docs = {
      description = "Obsidian Headless Sync (mill-docs)";
      after = [
        "network-online.target"
        "obsidian-sync-op-env.service"
        "obsidian-sync.service"
      ];
      requires = [ "obsidian-sync-op-env.service" ];
      wants = [
        "network-online.target"
        "obsidian-sync.service"
      ];
      wantedBy = [ "multi-user.target" ];
      unitConfig.JoinsNamespaceOf = "obsidian-sync.service";

      serviceConfig = {
        Type = "simple";
        User = "emiller";
        Group = "users";
        ExecStartPre = [
          "${millDocsObsidianLoginScript}"
          "${millDocsObsidianSetupScript}"
          "${millDocsObsidianConfigScript}"
        ];
        ExecStart = "${millDocsObsidianSyncScript}";
        Restart = "on-failure";
        RestartSec = "30s";
        EnvironmentFile = "/run/obsidian-sync-op.env";
        Environment = "XDG_CONFIG_HOME=/tmp";
        ProtectHome = "read-only";
        ReadWritePaths = [ millDocsVaultPath ];
        NoNewPrivileges = true;
        PrivateTmp = true;
      };
    };
  };

  # FIXME https://discourse.nixos.org/t/logrotate-config-fails-due-to-missing-group-30000/28501/7
  services.logrotate.checkConfig = false;

  users.users.emiller.hashedPasswordFile = config.age.secrets.emiller_password.path;

  # opnix: 1Password service account token bootstrapped at /etc/opnix-token
  # Bootstrap (one-time): op read "op://Private/xkq3yij62kltcldkmk7qgkq66a/credential" \
  #   | ssh nuc "sudo tee /etc/opnix-token && sudo chmod 640 /etc/opnix-token"
  # The token file is read by OpNix + services that consume 1Password-backed secrets.

  age = {
    secrets = {
      lubelogger-env.owner = "lubelogger";
      bugster-env.owner = "emiller";
      speedtest-tracker-env.owner = "root";
      linear-refresh-token.owner = "emiller";
    };
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
