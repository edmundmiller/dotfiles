# Go nuc yourself (2026-02-26)
{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:
let
  hostSystem = pkgs.stdenv.hostPlatform.system;
  hermesAgentBase = inputs.hermesAgent.packages.${hostSystem}.default;
  anneHermesLauncher = inputs.agents-workspace.packages.${hostSystem}.anne-hermes;
  radarHermesLauncher = inputs.agents-workspace.packages.${hostSystem}.radar-hermes;
  discordBindings = import (inputs.agents-workspace + /deployments/nuc/discord-bindings.nix) {
    inherit lib;
  };
  anneDiscordBindings = (discordBindings.agents or { }).anne or { };
  anneHermesGateway = pkgs.writeShellScript "hermes-anne-discord-gateway" ''
    export PATH=${
      lib.escapeShellArg (
        lib.makeBinPath [
          anneHermesLauncher
          hermesAgentBase
          pkgs.bashInteractive
          pkgs.coreutils
          pkgs.findutils
          pkgs.git
          pkgs.python3
        ]
      )
    }:$PATH
    exec ${anneHermesLauncher}/bin/anne-hermes gateway run --replace
  '';
  anneDiscordHealthcheckPingUrl = "https://hc-ping.com/ca6df6ed-46f4-4c33-ae98-fb210e0dd617";
  scintillateHealthcheckPingUrl = "https://hc-ping.com/c2f20a37-1ac6-4184-bb4c-b35ac983ca61";
  # Telegram routing topology for this host:
  # - "hermes" => current/live mode; Hermes owns all Telegram on the current bot token
  # - "split"  => prepared future split; the shared bot keeps family/group traffic,
  #                while Hermes owns Scintillate DM on a dedicated Telegram bot token

  # Binding runtime controls whether the shared Telegram bindings keep the
  # Scintillate DM binding. Leave this at "hermes" for both current mode and
  # split mode so family/group routing stays separate while Hermes owns
  # Scintillate DM.
  telegramBindingRuntime = "hermes";
  telegramBindingsModule =
    let
      telegramBindingsPath = inputs.agents-workspace + /deployments/nuc/telegram-bindings.nix;
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
  # Scintillate should always answer as the dedicated Scintillate Telegram bot,
  # even while Hermes owns Telegram directly in the current deployment mode.
  # The shared family/group bot can stay separate from Scintillate's DM bot.
  hermesScintillateTelegramBotTokenFile = config.age.secrets.telegram-bot-token-scintillate.path;
  linearTokenFile = "/home/emiller/.local/state/hermes-linear/token";
  mkAgentSecret = envVar: secretName: {
    inherit envVar;
    inherit (config.age.secrets.${secretName}) path;
  };
  hermesProviderSecrets = [
    (mkAgentSecret "AGENTMAIL_API_KEY" "agentmail-api-key")
    (mkAgentSecret "ANTHROPIC_API_KEY" "anthropic-api-key")
    (mkAgentSecret "ELEVENLABS_API_KEY" "elevenlabs-api-key")
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
    {
      envVar = "FIRECRAWL_API_KEY";
      inherit (config.age.secrets.scintillate-firecrawl-api) path;
    }
  ];
  hermesBettySecrets = hermesProviderSecrets ++ [
    {
      envVar = "TELEGRAM_BOT_TOKEN";
      path = hermesScintillateTelegramBotTokenFile;
    }
  ];
  hermesAnneSecrets = hermesProviderSecrets ++ [
    {
      envVar = "DISCORD_BOT_TOKEN";
      inherit (config.age.secrets.discord-bot-token-anne) path;
    }
    {
      envVar = "FIRECRAWL_API_KEY";
      inherit (config.age.secrets.anne-firecrawl-api) path;
    }
  ];
  hermesRadarSecrets =
    (builtins.filter (
      secret:
      !(builtins.elem secret.envVar [
        "AGENTMAIL_API_KEY"
        "HA_TOKEN"
        "HASS_TOKEN"
      ])
    ) hermesProviderSecrets)
    ++ [
      {
        envVar = "AGENTMAIL_API_KEY";
        path = "/var/lib/opnix/secrets/radarAgentmailCredential";
      }
      {
        envVar = "EMAIL_PASSWORD";
        path = "/var/lib/opnix/secrets/radarAgentmailCredential";
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
  tnoteBaseRepo = "/home/emiller/src/personal/tnote";
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

    # The upstream hermes-agent module declares a dep on setupSecrets
    # (sops-nix convention) but we use agenix. Provide a no-op stub.
    setupSecrets = {
      text = ""; # no-op: agenix handles secrets via agenixInstall
      deps = [ ];
    };

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

    hermesScintillateSecretsMaterialize = {
      deps = [
        "agenixInstall"
        "agenixChown"
      ];
      text = ''
        ENV_DIR="/run/hermes-scintillate-env"
        ENV_FILE="$ENV_DIR/secrets.env"
        HERMES_ENV_HOME="/var/lib/hermes-scintillate/.hermes"
        HERMES_VOICE_MODE_FILE="$HERMES_ENV_HOME/gateway_voice_mode.json"

        mkdir -p "$ENV_DIR"
        : > "$ENV_FILE"
        chmod 600 "$ENV_FILE"

        printf 'HERMES_HONCHO_HOST=%s\n' "scintillate" >> "$ENV_FILE"

        ${lib.concatMapStringsSep "\n" (secret: ''
          if [ -f ${lib.escapeShellArg (toString secret.path)} ]; then
            secret_value="$(< ${lib.escapeShellArg (toString secret.path)})"
            printf '%s=%s\n' ${lib.escapeShellArg secret.envVar} "$secret_value" >> "$ENV_FILE"
          fi
        '') hermesScintillateSecrets}
        printf 'TELEGRAM_ALLOWED_USERS=%s\n' '8357890648' >> "$ENV_FILE"

        ${pkgs.python3}/bin/python - "$HERMES_VOICE_MODE_FILE" <<'PY'
        import json
        import pathlib
        import sys

        path = pathlib.Path(sys.argv[1])
        data = {}
        if path.exists():
            try:
                data = json.loads(path.read_text(encoding="utf-8")) or {}
            except Exception:
                data = {}
        data.pop("8357890648", None)
        path.write_text(json.dumps(data, indent=2) + "\n", encoding="utf-8")
        PY
        chown emiller:users "$HERMES_VOICE_MODE_FILE"
        chmod 600 "$HERMES_VOICE_MODE_FILE"
      '';
    };

    hermesAnneSecretsMaterialize = {
      deps = [
        "agenixInstall"
        "agenixChown"
      ];
      text = ''
        ANNE_STATE_DIR="/var/lib/hermes-anne"
        ENV_DIR="/run/hermes-anne-env"
        ENV_FILE="$ENV_DIR/secrets.env"
        HERMES_ENV_HOME="$ANNE_STATE_DIR/.hermes"
        HERMES_VOICE_MODE_FILE="$HERMES_ENV_HOME/gateway_voice_mode.json"

        install -d -o emiller -g users -m 0750 \
          "$ANNE_STATE_DIR" \
          "$ANNE_STATE_DIR/.codex" \
          "$ANNE_STATE_DIR/.local" \
          "$ANNE_STATE_DIR/.local/state" \
          "$ANNE_STATE_DIR/.local/state/hermes" \
          "$ANNE_STATE_DIR/.local/state/hermes/gateway-locks" \
          "$HERMES_ENV_HOME" \
          "$HERMES_ENV_HOME/.codex" \
          "$HERMES_ENV_HOME/workspace" \
          "$HERMES_ENV_HOME/workspace/repos"

        ln -sfn /home/emiller/.codex/auth.json "$ANNE_STATE_DIR/.codex/auth.json"
        chown -h emiller:users "$ANNE_STATE_DIR/.codex/auth.json"
        ln -sfn /home/emiller/.codex/auth.json "$HERMES_ENV_HOME/.codex/auth.json"
        chown -h emiller:users "$HERMES_ENV_HOME/.codex/auth.json"
        ln -sfn ${millDocsVaultPath} "$ANNE_STATE_DIR/mill-docs"
        chown -h emiller:users "$ANNE_STATE_DIR/mill-docs"
        ln -sfn /home/emiller/obsidian-vault "$ANNE_STATE_DIR/obsidian-vault"
        chown -h emiller:users "$ANNE_STATE_DIR/obsidian-vault"

        ln -sfn ${millDocsVaultPath} "$HERMES_ENV_HOME/workspace/repos/mill-docs"
        chown -h emiller:users "$HERMES_ENV_HOME/workspace/repos/mill-docs"
        ln -sfn /home/emiller/obsidian-vault "$HERMES_ENV_HOME/workspace/repos/obsidian-vault"
        chown -h emiller:users "$HERMES_ENV_HOME/workspace/repos/obsidian-vault"

        mkdir -p "$ENV_DIR"
        : > "$ENV_FILE"
        chmod 600 "$ENV_FILE"
        chown emiller:users "$ENV_FILE"

        printf 'HERMES_HONCHO_HOST=%s\n' "anne" >> "$ENV_FILE"

        ${lib.concatMapStringsSep "\n" (secret: ''
          if [ -f ${lib.escapeShellArg (toString secret.path)} ]; then
            secret_value="$(cat ${lib.escapeShellArg (toString secret.path)})"
            printf '%s=%s\n' ${lib.escapeShellArg secret.envVar} "$secret_value" >> "$ENV_FILE"
          fi
        '') hermesAnneSecrets}

        if [ -f /etc/opnix-token ]; then
          OP_SERVICE_ACCOUNT_TOKEN="$(cat /etc/opnix-token)"
          export OP_SERVICE_ACCOUNT_TOKEN
          if linear_token="$(${pkgs._1password-cli}/bin/op read 'op://Agents/Anne Hermes Bot Linear Token/credential' 2>/dev/null)" && [ -n "$linear_token" ]; then
            printf 'HERMES_MCP_BEARER_TOKEN_LINEAR=%s\n' "$linear_token" >> "$ENV_FILE"
          fi
          unset linear_token OP_SERVICE_ACCOUNT_TOKEN
        fi

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

        ${pkgs.python3}/bin/python - "$HERMES_VOICE_MODE_FILE" ${lib.escapeShellArg (toString anneDiscordBindings.homeChannelId)} <<'PY'
        import json
        import pathlib
        import sys

        path = pathlib.Path(sys.argv[1])
        chat_id = sys.argv[2].strip()
        data = {}
        if path.exists():
            try:
                data = json.loads(path.read_text(encoding="utf-8")) or {}
            except Exception:
                data = {}
        if chat_id:
            data[chat_id] = "all"
        path.write_text(json.dumps(data, indent=2) + "\n", encoding="utf-8")
        PY
        chown emiller:users "$HERMES_VOICE_MODE_FILE"
        chmod 600 "$HERMES_VOICE_MODE_FILE"
      '';
    };

    hermesBettySecretsMaterialize = {
      deps = [
        "agenixInstall"
        "agenixChown"
      ];
      text = ''
        BETTY_HOME="/var/lib/hermes-betty"
        ENV_DIR="/run/hermes-betty-env"
        ENV_FILE="$ENV_DIR/secrets.env"
        HERMES_ENV_HOME="$BETTY_HOME/.hermes"

        install -d -o emiller -g users -m 0750 "$BETTY_HOME"
        install -d -o emiller -g users -m 0750 "$HERMES_ENV_HOME"
        install -d -o emiller -g users -m 0750 "$HERMES_ENV_HOME/workspace"
        install -d -o emiller -g users -m 0750 "$HERMES_ENV_HOME/workspace/repos"
        install -d -o emiller -g users -m 0750 "$HERMES_ENV_HOME/.codex"
        install -d -o emiller -g users -m 0750 "$BETTY_HOME/.codex"
        install -d -o emiller -g users -m 0750 "$BETTY_HOME/.local"
        install -d -o emiller -g users -m 0750 "$BETTY_HOME/.local/state"
        install -d -o emiller -g users -m 0750 "$BETTY_HOME/.local/state/hermes"
        install -d -o emiller -g users -m 0750 "$BETTY_HOME/.local/state/hermes/gateway-locks"

        ln -sfn /home/emiller/.codex/auth.json "$BETTY_HOME/.codex/auth.json"
        chown -h emiller:users "$BETTY_HOME/.codex/auth.json"
        ln -sfn /home/emiller/.codex/auth.json "$HERMES_ENV_HOME/.codex/auth.json"
        chown -h emiller:users "$HERMES_ENV_HOME/.codex/auth.json"
        ln -sfn /home/emiller/obsidian-vault "$HERMES_ENV_HOME/workspace/repos/obsidian-vault"
        chown -h emiller:users "$HERMES_ENV_HOME/workspace/repos/obsidian-vault"
        ln -sfn /home/emiller/obsidian-vault "$BETTY_HOME/obsidian-vault"
        chown -h emiller:users "$BETTY_HOME/obsidian-vault"

        mkdir -p "$ENV_DIR"
        : > "$ENV_FILE"
        chmod 600 "$ENV_FILE"
        chown emiller:users "$ENV_FILE"

        printf 'HERMES_HONCHO_HOST=%s\n' "betty" >> "$ENV_FILE"

        ${lib.concatMapStringsSep "\n" (secret: ''
          if [ -f ${lib.escapeShellArg (toString secret.path)} ]; then
            secret_value="$(cat ${lib.escapeShellArg (toString secret.path)})"
            printf '%s=%s\n' ${lib.escapeShellArg secret.envVar} "$secret_value" >> "$ENV_FILE"
          fi
        '') hermesBettySecrets}
      '';
    };

    hermesRadarSecretsMaterialize = {
      deps = [
        "agenixInstall"
        "agenixChown"
      ];
      text = ''
        RADAR_HOME="/var/lib/hermes-radar"
        ENV_DIR="/run/hermes-radar-env"
        ENV_FILE="$ENV_DIR/secrets.env"
        HERMES_ENV_HOME="$RADAR_HOME/.hermes"

        install -d -o emiller -g users -m 0750 "$RADAR_HOME"
        install -d -o emiller -g users -m 0750 "$HERMES_ENV_HOME"
        install -d -o emiller -g users -m 0750 "$HERMES_ENV_HOME/workspace"
        install -d -o emiller -g users -m 0750 "$HERMES_ENV_HOME/workspace/repos"
        install -d -o emiller -g users -m 0750 "$HERMES_ENV_HOME/.codex"
        install -d -o emiller -g users -m 0750 "$RADAR_HOME/.codex"
        install -d -o emiller -g users -m 0750 "$RADAR_HOME/.local"
        install -d -o emiller -g users -m 0750 "$RADAR_HOME/.local/state"
        install -d -o emiller -g users -m 0750 "$RADAR_HOME/.local/state/hermes"
        install -d -o emiller -g users -m 0750 "$RADAR_HOME/.local/state/hermes/gateway-locks"

        ln -sfn /home/emiller/.codex/auth.json "$RADAR_HOME/.codex/auth.json"
        chown -h emiller:users "$RADAR_HOME/.codex/auth.json"
        ln -sfn /home/emiller/.codex/auth.json "$HERMES_ENV_HOME/.codex/auth.json"
        chown -h emiller:users "$HERMES_ENV_HOME/.codex/auth.json"
        ln -sfn /home/emiller/obsidian-vault "$HERMES_ENV_HOME/workspace/repos/obsidian-vault"
        chown -h emiller:users "$HERMES_ENV_HOME/workspace/repos/obsidian-vault"
        ln -sfn /home/emiller/obsidian-vault "$RADAR_HOME/obsidian-vault"
        chown -h emiller:users "$RADAR_HOME/obsidian-vault"

        mkdir -p "$ENV_DIR"
        : > "$ENV_FILE"
        chmod 600 "$ENV_FILE"
        chown emiller:users "$ENV_FILE"

        printf 'HERMES_HONCHO_HOST=%s\n' "radar" >> "$ENV_FILE"

        ${lib.concatMapStringsSep "\n" (secret: ''
          if [ -f ${lib.escapeShellArg (toString secret.path)} ]; then
            secret_value="$(cat ${lib.escapeShellArg (toString secret.path)})"
            printf '%s=%s\n' ${lib.escapeShellArg secret.envVar} "$secret_value" >> "$ENV_FILE"
          fi
        '') hermesRadarSecrets}

        printf 'TELEGRAM_ALLOWED_USERS=%s\n' '8357890648' >> "$ENV_FILE"
      '';
    };

    hermesBettyWorkspaceCompat = {
      deps = [ ];
      text = ''
        BETTY_HOME="/var/lib/hermes-betty"

        install -d -o emiller -g users -m 0750 "$BETTY_HOME/.local/bin"
        install -d -o emiller -g users -m 0750 "$BETTY_HOME/home/emiller"

        ln -sfn /home/emiller/.local/bin/tnote "$BETTY_HOME/.local/bin/tnote"
        ln -sfn /home/emiller/obsidian-vault "$BETTY_HOME/obsidian-vault"
        ln -sfn ${millDocsVaultPath} "$BETTY_HOME/home/emiller/mill-docs"

        chown -h emiller:users "$BETTY_HOME/.local/bin/tnote"
        chown -h emiller:users "$BETTY_HOME/obsidian-vault"
        chown -h emiller:users "$BETTY_HOME/home/emiller/mill-docs"
      '';
    };

    tnoteWrapper = {
      deps = [ "users" ];
      text = ''
        BASE_REPO=${lib.escapeShellArg tnoteBaseRepo}

        install -d -o emiller -g users -m 0750 /home/emiller/.local/bin

        cat > /home/emiller/.local/bin/tnote <<'EOF'
        #!/usr/bin/env bash
        set -euo pipefail

        REPO="$HOME/src/personal/tnote"
        DEFAULT_VAULT="$HOME/obsidian-vault"

        export TN_VAULT_PATH="''${TN_VAULT_PATH:-$DEFAULT_VAULT}"
        quoted_args="$(printf '%q ' "$@")"

        if [ ! -f "$REPO/packages/tn/index.ts" ]; then
          echo "tnote repo missing expected entrypoint: $REPO/packages/tn/index.ts" >&2
          exit 1
        fi

        cd "$REPO"
        exec nix-shell -p bun --run "TN_VAULT_PATH=$(printf '%q' "$TN_VAULT_PATH") bun run packages/tn/index.ts ''${quoted_args}"
        EOF
        chown emiller:users /home/emiller/.local/bin/tnote
        chmod 0755 /home/emiller/.local/bin/tnote

        if [ ! -d "$BASE_REPO/.git" ]; then
          echo "Skipping tnote dependency install; base repo missing at $BASE_REPO" >&2
          exit 0
        fi

        ${pkgs.util-linux}/bin/runuser -u emiller -- \
          ${pkgs.coreutils}/bin/env HOME=/home/emiller \
          ${pkgs.bun}/bin/bun install --cwd "$BASE_REPO" --ignore-scripts
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
          if ${pkgs.util-linux}/bin/runuser -u emiller -- \
            ${pkgs.systemd}/bin/systemctl --user list-unit-files hermes-gateway-scintillate.service --no-legend 2>/dev/null \
            | ${pkgs.gnugrep}/bin/grep -q '^hermes-gateway-scintillate\.service'; then
            ${pkgs.util-linux}/bin/runuser -u emiller -- \
              ${pkgs.systemd}/bin/systemctl --user disable --now hermes-gateway-scintillate.service || true
            ${pkgs.util-linux}/bin/runuser -u emiller -- \
              ${pkgs.systemd}/bin/systemctl --user reset-failed hermes-gateway-scintillate.service || true
            ${pkgs.util-linux}/bin/runuser -u emiller -- \
              ${pkgs.systemd}/bin/systemctl --user daemon-reload || true
          fi
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
    (python3.withPackages (
      ps: with ps; [
        google-api-python-client
        google-auth-oauthlib
        google-auth-httplib2
      ]
    )) # For node-gyp (pi-interactive-shell/node-pty) and Scintillate Google Workspace skill deps
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
    package = hermesAgentBase;
    user = "emiller";
    group = "users";
    createUser = false;
    profiles = {
      anne = {
        authFile = "/home/emiller/.codex/auth.json";
        environment.CODEX_HOME = "/home/emiller/.codex";
      };
      betty = {
        authFile = "/home/emiller/.codex/auth.json";
        environment.CODEX_HOME = "/home/emiller/.codex";
        workingDirectory = "/home/emiller/mill-docs";
      };
      scintillate = {
        authFile = "/home/emiller/.codex/auth.json";
        environment.CODEX_HOME = "/home/emiller/.codex";
      };
      amosburton = {
        authFile = "/home/emiller/.codex/auth.json";
        environment.CODEX_HOME = "/home/emiller/.codex";
      };
    };
  };

  systemd.services.hermes-gateway-anne.serviceConfig = {
    EnvironmentFile = [ "/run/hermes-anne-env/secrets.env" ];
    ExecStartPre = [
      "${pkgs.coreutils}/bin/test -f /home/emiller/.codex/auth.json"
      "${pkgs.coreutils}/bin/test -f /var/lib/hermes-anne/.codex/auth.json"
    ];
    ExecStart = lib.mkForce anneHermesGateway;
  };

  systemd.services.hermes-gateway-scintillate.serviceConfig = {
    EnvironmentFile = [ "/run/hermes-scintillate-env/secrets.env" ];
  };

  systemd.services.hermes-radar-cron-tick = {
    description = "Run Radar cron jobs without an interactive gateway";
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    path = [
      radarHermesLauncher
      hermesAgentBase
      pkgs.bashInteractive
      pkgs.coreutils
      pkgs.findutils
      pkgs.git
      pkgs.python3
    ];
    serviceConfig = {
      Type = "oneshot";
      User = "emiller";
      Group = "users";
      WorkingDirectory = "/var/lib/hermes-radar";
      EnvironmentFile = [ "/run/hermes-radar-env/secrets.env" ];
      Environment = [
        "HOME=/var/lib/hermes-radar"
        "HERMES_HOME=/var/lib/hermes-radar/.hermes"
        "HERMES_PROFILE=radar"
        "MESSAGING_CWD=/var/lib/hermes-radar/.hermes/workspace"
        "CODEX_HOME=/home/emiller/.codex"
        "EMAIL_ADDRESS=norbot@agentmail.to"
        "EMAIL_IMAP_HOST=imap.agentmail.to"
        "EMAIL_IMAP_PORT=993"
        "EMAIL_SMTP_HOST=smtp.agentmail.to"
        "EMAIL_SMTP_PORT=465"
        "EMAIL_HOME_ADDRESS=emiller@edmundmiller.dev"
      ];
      ExecStart = "${radarHermesLauncher}/bin/radar-hermes cron tick";
      NoNewPrivileges = true;
      PrivateTmp = true;
      ProtectHome = false;
      ProtectSystem = "strict";
      ReadWritePaths = [ "/var/lib/hermes-radar" ];
    };
  };

  systemd.timers.hermes-radar-cron-tick = {
    description = "Run Radar background cron jobs on a timer";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = "2min";
      OnUnitActiveSec = "5min";
      RandomizedDelaySec = "30s";
      Unit = "hermes-radar-cron-tick.service";
    };
  };

  systemd.services.hermes-gateway-radar.enable = false;

  systemd.services.hermes-gateway-betty.serviceConfig.ReadWritePaths = [
    "/var/lib/hermes-betty"
    "/home/emiller/mill-docs"
  ];

  systemd.services.hermes-agent-anne-healthcheck-ping = {
    description = "Check Anne Discord gateway health and ping healthchecks.io";
    after = [ "hermes-gateway-anne.service" ];
    wants = [ "hermes-gateway-anne.service" ];
    serviceConfig = {
      Type = "oneshot";
      DynamicUser = true;
      TimeoutStartSec = 90;
      ExecStartPre = "-${pkgs.curl}/bin/curl -sS -m 10 --retry 5 ${anneDiscordHealthcheckPingUrl}/start";
      ExecStart = pkgs.writeShellScript "hermes-agent-anne-healthcheck-ping" ''
        for _ in $(seq 1 90); do
          if ${pkgs.systemd}/bin/systemctl is-active --quiet hermes-gateway-anne.service; then
            exit 0
          fi
          sleep 1
        done
        exit 1
      '';
      ExecStopPost = "${pkgs.curl}/bin/curl -sS -m 10 --retry 5 ${anneDiscordHealthcheckPingUrl}/\${EXIT_STATUS}";
    };
  };

  systemd.timers.hermes-agent-anne-healthcheck-ping = {
    description = "Ping healthchecks.io for Anne Discord gateway";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = "2min";
      OnUnitActiveSec = "2min";
      RandomizedDelaySec = "10s";
    };
  };

  systemd.services.hermes-scintillate-healthcheck-ping = {
    description = "Check Scintillate gateway health and ping healthchecks.io";
    after = [ "hermes-gateway-scintillate.service" ];
    wants = [ "hermes-gateway-scintillate.service" ];
    serviceConfig = {
      Type = "oneshot";
      DynamicUser = true;
      ExecStartPre = "-${pkgs.curl}/bin/curl -sS -m 10 --retry 5 ${scintillateHealthcheckPingUrl}/start";
      ExecStart = pkgs.writeShellScript "hermes-scintillate-healthcheck-ping" ''
        for _ in $(seq 1 30); do
          if ${pkgs.systemd}/bin/systemctl is-active --quiet hermes-gateway-scintillate.service; then
            exit 0
          fi
          sleep 1
        done
        exit 1
      '';
      ExecStopPost = "${pkgs.curl}/bin/curl -sS -m 10 --retry 5 ${scintillateHealthcheckPingUrl}/\${EXIT_STATUS}";
    };
  };

  systemd.timers.hermes-scintillate-healthcheck-ping = {
    description = "Ping healthchecks.io for Scintillate gateway";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = "1min";
      OnUnitActiveSec = "2min";
      RandomizedDelaySec = "10s";
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
      hermes = {
        enable = true;
        agents = {
          scintillate = {
            workspaceLinks."repos/obsidian-vault" = "/home/emiller/obsidian-vault";
            workspaceLinks."repos/tnote" = tnoteBaseRepo;
            mcpBearerTokenPaths.linear = config.age.secrets.scintillate-linear-mcp-token.path;
          };

          betty = {
            workspaceLinks."repos/mill-docs" = "/home/emiller/mill-docs";
            workspaceLinks."repos/obsidian-vault" = "/home/emiller/obsidian-vault";
            workspaceLinks."repos/tnote" = tnoteBaseRepo;
          };
          anne = { };
          # Radar intentionally disabled on NUC until its HA endpoint/runtime is fixed.
          amosburton = {
            workspaceLinks."repos/agents-workspace" = "/home/emiller/src/personal/agents-workspace";
            workspaceLinks."repos/dotfiles" = "/home/emiller/.config/dotfiles";
            workspaceLinks."repos/finances" = "/home/emiller/src/personal/finances";
            workspaceLinks."repos/obsidian-vault" = "/home/emiller/obsidian-vault";
            workspaceLinks."repos/tailnet" = "/home/emiller/src/personal/tailnet";
          };

        };
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
      mission-control = {
        enable = true;
        tailscaleService.enable = true;
        environmentFile = config.age.secrets.mission-control-env.path;
        registeredAgents = [
          {
            name = "scintillate";
            role = "assistant";
            framework = "hermes";
            capabilities = [
              "memory"
              "notes"
              "planning"
              "writing"
            ];
          }
          {
            name = "anne";
            role = "assistant";
            framework = "hermes";
            capabilities = [
              "memory"
              "notes"
              "planning"
              "writing"
            ];
          }
          {
            name = "betty";
            role = "assistant";
            framework = "hermes";
            capabilities = [
              "browser"
              "calendar"
              "mail"
              "memory"
              "notes"
              "planning"
              "writing"
            ];
          }
        ];
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

      # dagster.webserver.port = 3001; # temporarily disabled: dagster protobuf version mismatch

      finances-dagster = {
        enable = false; # temporarily disabled: dagster protobuf version mismatch
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
          tasksDir = "01_Tasks";
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
  systemd.tmpfiles.rules = [
    "d ${millDocsVaultPath} 0755 emiller users -"
  ];

  systemd.services.obsidian-sync-mill-docs = {
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

  # Replay Echo on iOS can fail SSH negotiation with newer OpenSSH defaults.
  # Keep modern defaults, but explicitly allow legacy RSA + group14-sha1 fallback.
  services.openssh.settings = {
    # Replay Echo / NIOSSH compatibility: keep modern algorithms but avoid
    # bleeding-edge-only defaults that some mobile SSH stacks choke on.
    KexAlgorithms = [
      "curve25519-sha256"
      "curve25519-sha256@libssh.org"
      "ecdh-sha2-nistp256"
      "ecdh-sha2-nistp384"
      "ecdh-sha2-nistp521"
      "diffie-hellman-group14-sha256"
      "diffie-hellman-group14-sha1"
    ];
    Ciphers = [
      "chacha20-poly1305@openssh.com"
      "aes256-ctr"
      "aes192-ctr"
      "aes128-ctr"
      "aes256-gcm@openssh.com"
      "aes128-gcm@openssh.com"
    ];
    Macs = [
      "hmac-sha2-512"
      "hmac-sha2-256"
      "hmac-sha1"
    ];
    HostKeyAlgorithms = "ssh-ed25519,ecdsa-sha2-nistp256,ecdsa-sha2-nistp384,ecdsa-sha2-nistp521,rsa-sha2-512,rsa-sha2-256,ssh-rsa";
    PubkeyAcceptedAlgorithms = "ssh-ed25519,sk-ssh-ed25519@openssh.com,ecdsa-sha2-nistp256,ecdsa-sha2-nistp384,ecdsa-sha2-nistp521,sk-ecdsa-sha2-nistp256@openssh.com,rsa-sha2-512,rsa-sha2-256,ssh-rsa";
    PerSourcePenalties = "no";
  };

  # FIXME https://discourse.nixos.org/t/logrotate-config-fails-due-to-missing-group-30000/28501/7
  services.logrotate.checkConfig = false;

  users.users.emiller.hashedPasswordFile = config.age.secrets.emiller_password.path;

  # opnix: 1Password service account token bootstrapped at /etc/opnix-token
  # Bootstrap (one-time): op read "op://Private/xkq3yij62kltcldkmk7qgkq66a/credential" \
  #   | ssh nuc "sudo tee /etc/opnix-token && sudo chmod 640 /etc/opnix-token"
  # The token file is read by OpNix + services that consume 1Password-backed secrets.

  services.onepassword-secrets = {
    enable = true;
    secrets = {
      anneHermesHonchoApiKey = {
        reference = "op://Agents/Anne Honcho Key/credential";
      };
      scintillateHermesHonchoApiKey = {
        reference = "op://Agents/scintillate Honcho Key/credential";
      };
      radarAgentmailCredential = {
        reference = "op://Agents/Radar Agentmail/credential";
      };
    };
  };

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
