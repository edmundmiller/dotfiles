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
  hermesAgentUpstream = inputs.hermes-agent.packages.${hostSystem}.messaging;
  hermesPhotonSidecar = pkgs.buildNpmPackage {
    pname = "hermes-photon-sidecar";
    version = hermesAgentUpstream.version or "0.17.0";
    src = "${hermesAgentUpstream}/share/hermes-agent/plugins/platforms/photon/sidecar";
    npmDepsHash = "sha256-Z6yKhVlwv/PswOS3HyCmtvYGMgh/bnNZ46FjpyTJ7tE=";
    dontNpmBuild = true;
    installPhase = ''
      mkdir -p $out
      cp -R . $out/
    '';
  };
  honchoAi = pkgs.python313Packages.buildPythonPackage rec {
    pname = "honcho-ai";
    version = "2.1.2";
    format = "wheel";
    src = pkgs.fetchurl {
      url = "https://files.pythonhosted.org/packages/py3/h/honcho-ai/honcho_ai-${version}-py3-none-any.whl";
      hash = "sha256-oiIg8Bpj9qPB1GJarvChQld7g5gcQty2EXdjGGP7qk8=";
    };
    dependencies = with pkgs.python313Packages; [
      httpx
      pydantic
    ];
    doCheck = false;
  };
  rtkHermes = pkgs.python313Packages.buildPythonPackage rec {
    pname = "rtk-hermes";
    version = "1.2.3";
    pyproject = true;
    src = pkgs.fetchPypi {
      pname = "rtk_hermes";
      inherit version;
      hash = "sha256-tOljjbIXSZIdbuNfkb4AkHtZw3EKjEavq7BCs4/vFK8=";
    };
    build-system = with pkgs.python313Packages; [ setuptools ];
  };
  hermesCronPython =
    pkgs.runCommand "hermes-cron-executor-health"
      {
        nativeBuildInputs = [ pkgs.patch ];
      }
      ''
        site_packages="$out/${pkgs.python312.sitePackages}"
        mkdir -p "$site_packages"
        cp -RL --no-preserve=mode,ownership,timestamps \
          ${hermesAgentUpstream.hermesVenv}/${pkgs.python312.sitePackages}/hermes_cli \
          "$site_packages/hermes_cli"
        chmod -R u+w "$site_packages/hermes_cli"
        patch -d "$site_packages" -p1 < ${../../overlays/hermes-agent/patches/0003-report-external-cron-executor.patch}
      '';
  hermesAgentBase = pkgs.symlinkJoin {
    name = "${hermesAgentUpstream.name}-honcho";
    paths = [ hermesAgentUpstream ];
    nativeBuildInputs = [
      pkgs.makeWrapper
      pkgs.python3
    ];
    postBuild = ''
      photon_plugin="$out/share/hermes-agent/plugins/platforms/photon"
      photon_sidecar="$photon_plugin/sidecar"
      rm -rf "$photon_plugin"
      mkdir -p "$(dirname "$photon_plugin")"
      cp -R ${hermesAgentUpstream}/share/hermes-agent/plugins/platforms/photon "$photon_plugin"
      chmod -R u+w "$photon_plugin"
      rm -rf "$photon_sidecar"
      cp -R ${hermesPhotonSidecar} "$photon_sidecar"
      python - <<PY
      from pathlib import Path

      path = Path("$photon_plugin") / "cli.py"
      text = path.read_text()
      needle = "    # spectrum-ts is pinned exactly in package.json/package-lock.json because\\n"
      replacement = (
          "    if (_SIDECAR_DIR / \"node_modules\").exists():\\n"
          "        print(\"  sidecar deps already installed\")\\n"
          "        return 0\\n"
          + needle
      )
      if needle not in text:
          raise SystemExit("Photon sidecar install marker not found")
      path.write_text(text.replace(needle, replacement, 1))
      PY

      for exe in hermes hermes-agent hermes-acp; do
        rm -f "$out/bin/$exe"
        cp ${hermesAgentUpstream}/bin/$exe "$out/bin/$exe"
        chmod u+w "$out/bin/$exe"
        wrapProgram "$out/bin/$exe" \
          --prefix PYTHONPATH : "${hermesCronPython}/${pkgs.python312.sitePackages}:${honchoAi}/${pkgs.python313.sitePackages}:${rtkHermes}/${pkgs.python313.sitePackages}"
        substituteInPlace "$out/bin/.$exe-wrapped" \
          --replace-fail "${hermesAgentUpstream}/share/hermes-agent/plugins" "$out/share/hermes-agent/plugins"
      done
    '';
    inherit (hermesAgentUpstream) meta;
    passthru = hermesAgentUpstream.passthru or { };
  };
  hermesTelegramPythonPath = "${pkgs.python313Packages.python-telegram-bot}/${pkgs.python313.sitePackages}";
  amosburtonHermesLauncher = inputs.agents-workspace.packages.${hostSystem}.amosburton-hermes;
  amosburtonAgentSpec = import (inputs.agents-workspace + /agents/amosburton) { inherit lib; };
  bettyHermesLauncher = inputs.agents-workspace.packages.${hostSystem}.betty-hermes;
  bettyHermesCronExecutor = pkgs.writeShellScript "hermes-betty-cron-executor" ''
    set -eu
    export OP_SERVICE_ACCOUNT_TOKEN="$(${pkgs.coreutils}/bin/cat /etc/opnix-token)"
    exec ${bettyHermesLauncher}/bin/betty-hermes cron tick
  '';
  bettyDjPython = pkgs.python3.withPackages (ps: [ ps.websockets ]);
  bettyGoodMorningDjHelperText = builtins.readFile bettyAgentSpec.automations.goodMorningDj.helper;
  bettyGoodMorningDjPrompt = builtins.readFile bettyAgentSpec.automations.goodMorningDj.prompt;
  bettyGoodMorningDjHelper = pkgs.writeText "betty-good-morning-dj.py" bettyGoodMorningDjHelperText;
  bettyGoodMorningDjExecutor = pkgs.writeShellScript "betty-hermes-good-morning-dj" ''
    set -eu

    receipt_path="$(${pkgs.coreutils}/bin/mktemp)"
    cleanup() { ${pkgs.coreutils}/bin/rm -f "$receipt_path"; }
    trap cleanup EXIT

    ${bettyDjPython}/bin/python ${bettyGoodMorningDjHelper} prepare

    set +e
    ${bettyHermesLauncher}/bin/betty-hermes --oneshot ${lib.escapeShellArg bettyGoodMorningDjPrompt} >"$receipt_path" 2>/dev/null
    hermes_status=$?
    set -e

    # hermes --oneshot often SIGABRTs (134) during Py_Finalize after a completed
    # answer. Accept only 0/134 as candidates; receipt + MA queue decide success.
    case "$hermes_status" in
      0|134) ;;
      *)
        echo "betty good-morning-dj: hermes exited $hermes_status" >&2
        exit "$hermes_status"
        ;;
    esac

    ${bettyDjPython}/bin/python ${bettyGoodMorningDjHelper} verify "$receipt_path"
  '';
  bettyAgentSpec = import (inputs.agents-workspace + /agents/betty) { inherit lib; };
  bettyBookPlayer = pkgs.writeShellApplication {
    name = "betty-book-player";
    text = ''
      exec ${bettyDjPython}/bin/python ${bettyAgentSpec.automations.bookPlayer.helper} "$@"
    '';
  };
  radarHermesLauncher = inputs.agents-workspace.packages.${hostSystem}.radar-hermes;
  radarBlogwatcherCli = inputs.agents-workspace.packages.${hostSystem}.blogwatcher-cli;
  radarCronExecutor = pkgs.writeText "hermes-radar-cron-executor.json" ''
    {"kind":"systemd","unit":"hermes-radar-cron-tick.timer"}
  '';
  discordBindings = import (inputs.agents-workspace + /deployments/nuc/discord-bindings.nix) {
    inherit lib;
  };
  anneDiscordBindings = (discordBindings.agents or { }).anne or { };
  bettyDiscordBindings = (discordBindings.agents or { }).betty or { };
  hermesScintillateApiServerPort = 8642;
  hermesScintillateWebuiPort = 8787;
  hermesScintillateDesktopDashboardPort = 9121;
  hermesScintillateTailscaleServiceName = "hermes";
  hermesSharedStateDir = "/var/lib/hermes";
  hermesSharedHome = "${hermesSharedStateDir}/.hermes";
  hermesSharedProfileNames = [
    "amosburton"
    "anne"
    "betty"
    "orchestrator"
    "radar"
    "scintillate"
  ];
  hermesGatewayUnits = map (name: "hermes-gateway-${name}.service") hermesSharedProfileNames;
  hermesRuntimeSmoke = inputs.agents-workspace.packages.${hostSystem}.hermes-runtime-smoke;
  scintillateWhisperModel = pkgs.fetchurl {
    url = "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-base.en.bin";
    hash = "sha256-oDd5yG3zMjB19eeWyyzlAp8A7Ihp7uP9+4l6/jbG0AI=";
  };
  hermesWebuiSourceUnpatched = pkgs.fetchFromGitHub {
    owner = "nesquena";
    repo = "hermes-webui";
    rev = "396d0d0abd5c25ac7d1de8a73f240abb68c7f200";
    hash = "sha256-4EK0aF1zE45iDAJJooqkAy68kGlGitEhCy6q8/XC8RQ=";
  };
  hermesWebuiSource = pkgs.runCommand "hermes-webui-source-patched" { } ''
    cp -R ${hermesWebuiSourceUnpatched} $out
    chmod -R u+w $out
    OUT=$out ${pkgs.python3}/bin/python - <<'PY'
    import os
    from pathlib import Path

    path = Path(os.environ['OUT']) / 'api/profiles.py'
    text = path.read_text(encoding='utf-8')
    import re

    new = '\n'.join([
        '    # The NUC deployment aggregates independently managed Hermes roots into',
        '    # this WebUI via symlinks under $HERMES_BASE_HOME/profiles. The profile',
        '    # name is already strictly validated above, so avoid resolving the final',
        '    # symlink target before the containment check; otherwise legitimate',
        '    # symlinked profiles are rejected for living outside the base directory.',
        '    return profiles_root / name',
    ])
    text, count = re.subn(
        r"(?m)^    candidate = \(profiles_root / name\)\.resolve\(\)\n^    candidate\.relative_to\(profiles_root\)\n^    return candidate",
        new,
        text,
        count=1,
    )
    if count != 1:
        raise SystemExit('expected profile symlink containment block not found')
    path.write_text(text, encoding='utf-8')
    PY
  '';

  hermesWebuiPython = pkgs.python313.withPackages (ps: [
    ps.cryptography
    ps.httpx
    ps.python-dotenv
    ps.pyyaml
    ps.requests
    ps.websockets
  ]);
  hermesPythonSitePackages = "${hermesAgentBase}/${pkgs.python313.sitePackages}";
  tailnet = "cinnamon-rooster.ts.net";
  millDocsGitPullHealthcheckPingUrl = "https://hc-ping.com/1a661f7e-cf0c-4a67-9343-64635347c50d";
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
  amosburtonCronExecutor = pkgs.writeShellScript "hermes-amosburton-cron-executor" ''
    set -euo pipefail
    export OP_SERVICE_ACCOUNT_TOKEN="$(${pkgs.coreutils}/bin/cat /etc/opnix-token)"
    LINEAR_API_KEY="$(${pkgs._1password-cli}/bin/op read ${lib.escapeShellArg amosburtonAgentSpec.hermes.dotenvReferences.LINEAR_API_KEY})"
    export LINEAR_API_KEY
    unset HERMES_MCP_BEARER_TOKEN_LINEAR OP_SERVICE_ACCOUNT_TOKEN
    exec ${amosburtonHermesLauncher}/bin/amosburton-hermes cron tick
  '';
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
  hermesAmosburtonSecrets = hermesProviderSecrets;
  hermesScintillateSecrets = hermesProviderSecrets ++ [
    (mkAgentSecret "HONCHO_API_KEY" "hermes-scintillate-honcho-api-key")
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
  # Betty does not currently own a Telegram surface. Do not inject
  # Scintillate's bot token here: two Hermes gateways polling the same
  # Telegram bot produce getUpdates conflicts and make Scintillate flaky.
  hermesBettySecrets = hermesProviderSecrets ++ [
    (mkAgentSecret "HONCHO_API_KEY" "hermes-betty-honcho-api-key")
  ];
  hermesBetty1PasswordReferences = {
    inherit (bettyAgentSpec.hermes.dotenvReferences)
      DISCORD_BOT_TOKEN
      HERMES_SPOTIFY_CLIENT_ID
      LIFETIME_PASSWORD
      LIFETIME_USERNAME
      ;
    HERMES_MCP_BEARER_TOKEN_LINEAR = bettyAgentSpec.hermes.mcpBearerTokenReferences.linear;
  };
  hermesAnneSecrets = hermesProviderSecrets ++ [
    (mkAgentSecret "HONCHO_API_KEY" "hermes-anne-honcho-api-key")
    {
      envVar = "DISCORD_BOT_TOKEN";
      inherit (config.age.secrets.discord-bot-token-anne) path;
    }
    {
      envVar = "FIRECRAWL_API_KEY";
      inherit (config.age.secrets.anne-firecrawl-api) path;
    }
  ];
  hermesOrchestratorSecrets = hermesProviderSecrets ++ [
    (mkAgentSecret "HONCHO_API_KEY" "hermes-scintillate-honcho-api-key")
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
      (mkAgentSecret "HONCHO_API_KEY" "hermes-radar-honcho-api-key")
      {
        envVar = "AGENTMAIL_API_KEY";
        path = "/var/lib/opnix/secrets/radarAgentmailCredential";
      }
      {
        envVar = "EMAIL_PASSWORD";
        path = "/var/lib/opnix/secrets/radarAgentmailCredential";
      }
    ];
  hermesSecretSets = {
    amosburton = hermesAmosburtonSecrets;
    anne = hermesAnneSecrets;
    betty = hermesBettySecrets;
    orchestrator = hermesOrchestratorSecrets;
    radar = hermesRadarSecrets;
    scintillate = hermesScintillateSecrets;
  };
  hermesSecretEnvOwners =
    envVar:
    builtins.attrNames (
      lib.filterAttrs (
        _profile: secrets: builtins.any (secret: secret.envVar == envVar) secrets
      ) hermesSecretSets
    );
  hermesTelegramBotTokenOwners = hermesSecretEnvOwners "TELEGRAM_BOT_TOKEN";
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
  obsidianExcludedFolders = ".git,.beads,.claude,.github,.scripts,.opencode,.pi,.qmd,.tn,.config,.agents,.goose,.hooks,.pytest_cache,node_modules,TaskNotes,OLD_VAULT,.mdbase,.amp,scripts,.trash,.obsidian/plugins-disabled-20260505-160148,.obsidian/plugins-disabled-20260505-162506,.obsidian/plugins-disabled-all-20260505-164607,.obsidian/quarantine-resynced-corrupt-title-files-20260506-082607,.obsidian/quarantine-resynced-corrupt-title-files-20260506-082626,06_Attachments/YouTube,src";
  ob = "${pkgs.my.obsidian-headless}/bin/ob";
  op = "${pkgs._1password-cli}/bin/op";
  tnoteBaseRepo = "/home/emiller/src/personal/tnote";
  qmd = pkgs.writeShellScriptBin "qmd" ''
    export NODE_LLAMA_CPP_GPU=off
    exec ${pkgs.llm-agents.qmd}/bin/qmd "$@"
  '';
  nixPrivateGithub = pkgs.writeShellApplication {
    name = "nix-private-github";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.flock
      pkgs.git
    ];
    text = builtins.readFile ../../bin/nix-private-github;
  };
  himalayaFastmailSetupScript = pkgs.writeShellScript "hermes-scintillate-himalaya-fastmail-setup" ''
    set -eu

    op_token_file=/etc/opnix-token
    fastmail_item_ref=op://modfd4uzewmj55sff7jl6ihlzi/bvzeosvsl3jw2pinm3pq4ykpym
    config_dir=/var/lib/hermes-scintillate/home/.config/himalaya
    config_file="$config_dir/config.toml"
    password_dest="$config_dir/fastmail-app-password"

    test -s "$op_token_file"

    install -d -o emiller -g users -m 0700 "$config_dir"

    export HOME=/var/lib/hermes-scintillate/home
    export XDG_CONFIG_HOME=/var/lib/hermes-scintillate/home/.config
    export OP_SERVICE_ACCOUNT_TOKEN="$(cat "$op_token_file")"
    email="$(${op} read "$fastmail_item_ref/username" | ${pkgs.coreutils}/bin/tr -d '\r\n')"
    password="$(${op} read "$fastmail_item_ref/password")"

    printf '%s' "$password" | install -o emiller -g users -m 0600 /dev/stdin "$password_dest"
    unset password OP_SERVICE_ACCOUNT_TOKEN
    tmp_file="$config_file.tmp.$$"
    cat > "$tmp_file" <<EOF
    [accounts.fastmail]
    default = true
    email = "$email"

    folder.aliases.inbox = "INBOX"
    folder.aliases.sent = "Sent"
    folder.aliases.drafts = "Drafts"
    folder.aliases.trash = "Trash"
    folder.aliases.archive = "Archive"

    backend.type = "imap"
    backend.host = "imap.fastmail.com"
    backend.port = 993
    backend.login = "$email"
    backend.auth.type = "password"
    backend.auth.cmd = "cat /home/hermes/.config/himalaya/fastmail-app-password"

    message.send.backend.type = "smtp"
    message.send.backend.host = "smtp.fastmail.com"
    message.send.backend.port = 465
    message.send.backend.login = "$email"
    message.send.backend.auth.type = "password"
    message.send.backend.auth.cmd = "cat /home/hermes/.config/himalaya/fastmail-app-password"
    EOF

    install -o emiller -g users -m 0600 "$tmp_file" "$config_file"
    rm -f "$tmp_file"
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

  millDocsGitPullScript = pkgs.writeShellScript "mill-docs-git-pull" ''
    set -euo pipefail

    export PATH=${
      lib.makeBinPath [
        pkgs.git-lfs
        pkgs.openssh
      ]
    }:$PATH

    log_file="$(${pkgs.coreutils}/bin/mktemp)"
    exec > >(${pkgs.coreutils}/bin/tee -a "$log_file") 2>&1

    ping_healthcheck() {
      local url="$1"
      ${pkgs.curl}/bin/curl -fsS -m 10 --retry 5 --data-binary "@$log_file" "$url" >/dev/null || true
    }

    ${pkgs.curl}/bin/curl -fsS -m 10 --retry 5 '${millDocsGitPullHealthcheckPingUrl}/start' >/dev/null || true
    trap 'status=$?; if [ "$status" -eq 0 ]; then ping_healthcheck "${millDocsGitPullHealthcheckPingUrl}"; else ping_healthcheck "${millDocsGitPullHealthcheckPingUrl}/fail"; fi; rm -f "$log_file"; exit "$status"' EXIT

    cd '${millDocsVaultPath}'

    if ! ${pkgs.git}/bin/git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
      echo "${millDocsVaultPath} is not a git repository; skipping"
      exit 0
    fi

    if [ -d .git/rebase-merge ] || [ -d .git/rebase-apply ] || [ -f .git/MERGE_HEAD ]; then
      echo "git operation already in progress in ${millDocsVaultPath}; manual intervention required" >&2
      exit 1
    fi

    if ! ${pkgs.git}/bin/git rev-parse --abbrev-ref --symbolic-full-name '@{u}' >/dev/null 2>&1; then
      echo "current branch has no upstream; skipping git pull"
      exit 0
    fi

    ${pkgs.git}/bin/git pull --rebase --autostash
  '';

in
{
  assertions = telegramBindings.assertions ++ [
    {
      assertion = hermesTelegramBotTokenOwners == [ "scintillate" ];
      message = ''
        Scintillate must be the only NUC Hermes profile receiving TELEGRAM_BOT_TOKEN.
        Current owners: ${lib.concatStringsSep ", " hermesTelegramBotTokenOwners}
        Do not share one Telegram bot token across Hermes profiles; duplicate getUpdates polling breaks Telegram delivery.
      '';
    }
  ];

  nixpkgs.overlays = [
    (_final: prev: {
      pythonPackagesExtensions = prev.pythonPackagesExtensions ++ [
        (_pythonFinal: pythonPrev: {
          inline-snapshot = pythonPrev.inline-snapshot.overridePythonAttrs (old: {
            # Nixpkgs' Black version changes the generated documentation snippets.
            # Keep the package's 1,400+ behavioral tests while skipping those fixtures.
            disabledTests = (old.disabledTests or [ ]) ++ [ "test_docs" ];
          });
        })
      ];
    })
  ];

  system.activationScripts = {
    removeLegacyZele = ''
      rm -f /home/emiller/.bun/bin/zele /home/emiller/.cache/npm/bin/zele
    '';

    hermesRadarCronExecutor = {
      deps = [ "users" ];
      text = ''
        ${pkgs.coreutils}/bin/install -d -o emiller -g users -m 0700 /var/lib/hermes-radar/.hermes/cron
        ${pkgs.coreutils}/bin/install -o emiller -g users -m 0600 ${radarCronExecutor} /var/lib/hermes-radar/.hermes/cron/executor.json
      '';
    };

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

    hermesSharedProfilesAggregate = {
      deps = [ "canonical-hermes-profiles-materialize" ];
      text = ''
        SHARED_HOME=${lib.escapeShellArg hermesSharedHome}
        install -d -o emiller -g users -m 0750 "$SHARED_HOME" "$SHARED_HOME/profiles"

        if [ ! -f "$SHARED_HOME/profile.yaml" ]; then
          printf '%s\n' \
            'name: default' \
            'visible: false' \
            'role: shared-base' \
            > "$SHARED_HOME/profile.yaml"
          chown emiller:users "$SHARED_HOME/profile.yaml"
          chmod 0640 "$SHARED_HOME/profile.yaml"
        fi

        ${lib.concatMapStringsSep "\n" (profile: ''
          profile_home=${lib.escapeShellArg "/var/lib/hermes-${profile}/.hermes"}
          aggregate_link="$SHARED_HOME/profiles/${profile}"
          if [ -d "$profile_home" ] && [ ! -e "$aggregate_link" ]; then
            ln -s "$profile_home" "$aggregate_link"
            chown -h emiller:users "$aggregate_link"
          fi
          if [ -d "$profile_home" ] && [ ! -f "$profile_home/profile.yaml" ]; then
            printf '%s\n' \
              'name: ${profile}' \
              'visible: true' \
              'aggregated_into: /var/lib/hermes/.hermes/profiles/${profile}' \
              > "$profile_home/profile.yaml"
            chown emiller:users "$profile_home/profile.yaml"
            chmod 0640 "$profile_home/profile.yaml"
          fi
        '') hermesSharedProfileNames}

        if ls "$SHARED_HOME"/kanban.db* >/dev/null 2>&1; then
          chown emiller:users "$SHARED_HOME"/kanban.db* || true
        fi
      '';
    };

    hermesAmosburtonSecretsMaterialize = {
      deps = [
        "agenixInstall"
        "agenixChown"
      ];
      text = ''
        ENV_DIR="/run/hermes-amosburton-env"
        ENV_FILE="$ENV_DIR/secrets.env"

        mkdir -p "$ENV_DIR"
        : > "$ENV_FILE"
        chmod 600 "$ENV_FILE"
        chown emiller:users "$ENV_FILE"

        printf 'HERMES_HONCHO_HOST=%s\n' "amosburton" >> "$ENV_FILE"

        ${lib.concatMapStringsSep "\n" (secret: ''
          if [ -f ${lib.escapeShellArg (toString secret.path)} ]; then
            secret_value="$(< ${lib.escapeShellArg (toString secret.path)})"
            printf '%s=%s\n' ${lib.escapeShellArg secret.envVar} "$secret_value" >> "$ENV_FILE"
          fi
        '') hermesAmosburtonSecrets}
      '';
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
        printf 'API_SERVER_ENABLED=%s\n' "true" >> "$ENV_FILE"
        printf 'API_SERVER_HOST=%s\n' "0.0.0.0" >> "$ENV_FILE"
        printf 'API_SERVER_PORT=%s\n' "${toString hermesScintillateApiServerPort}" >> "$ENV_FILE"
        printf 'API_SERVER_CORS_ORIGINS=%s\n' "app://hermes-desktop,http://localhost:3000,http://127.0.0.1:3000,https://${hermesScintillateTailscaleServiceName}.${tailnet}" >> "$ENV_FILE"
        if [ -f ${lib.escapeShellArg (toString config.age.secrets.hermes-scintillate-api-server-key.path)} ]; then
          api_server_key="$(< ${lib.escapeShellArg (toString config.age.secrets.hermes-scintillate-api-server-key.path)})"
          printf 'API_SERVER_KEY=%s\n' "$api_server_key" >> "$ENV_FILE"
          unset api_server_key
        fi

        ${lib.concatMapStringsSep "\n" (secret: ''
          if [ -f ${lib.escapeShellArg (toString secret.path)} ]; then
            secret_value="$(< ${lib.escapeShellArg (toString secret.path)})"
            printf '%s=%s\n' ${lib.escapeShellArg secret.envVar} "$secret_value" >> "$ENV_FILE"
          fi
        '') hermesScintillateSecrets}
        printf 'TELEGRAM_ALLOWED_USERS=%s\n' '8357890648' >> "$ENV_FILE"
        printf 'TELEGRAM_HOME_CHANNEL=%s\n' '8357890648' >> "$ENV_FILE"

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
                ENV_TMP="$ENV_FILE.tmp.$$"
                HERMES_ENV_HOME="$BETTY_HOME/.hermes"

                cleanup() {
                  rm -f "$ENV_TMP"
                }
                trap cleanup EXIT

                install -d -o emiller -g users -m 0750 "$BETTY_HOME"
                install -d -o emiller -g users -m 0750 "$HERMES_ENV_HOME"
                install -d -o emiller -g users -m 0750 "$HERMES_ENV_HOME/workspace"
                install -d -o emiller -g users -m 0750 "$HERMES_ENV_HOME/workspace/repos"
                install -d -o emiller -g users -m 0750 "$BETTY_HOME/.codex"
                install -d -o emiller -g users -m 0750 "$BETTY_HOME/.local"
                install -d -o emiller -g users -m 0750 "$BETTY_HOME/.local/state"
                install -d -o emiller -g users -m 0750 "$BETTY_HOME/.local/state/hermes"
                install -d -o emiller -g users -m 0750 "$BETTY_HOME/.local/state/hermes/gateway-locks"

                if [ -L "$BETTY_HOME/.codex/auth.json" ] && [ "$(readlink "$BETTY_HOME/.codex/auth.json")" = /home/emiller/.codex/auth.json ]; then
                  rm -f "$BETTY_HOME/.codex/auth.json"
                fi
                if [ -f "$BETTY_HOME/.codex/auth.json" ] && [ -f /home/emiller/.codex/auth.json ] && ${pkgs.diffutils}/bin/cmp -s "$BETTY_HOME/.codex/auth.json" /home/emiller/.codex/auth.json; then
                  mv "$BETTY_HOME/.codex/auth.json" "$BETTY_HOME/.codex/auth.json.shared-seed-disabled"
                fi
                if [ -f "$HERMES_ENV_HOME/auth.json" ] && [ -f /home/emiller/.codex/auth.json ] && ${pkgs.diffutils}/bin/cmp -s "$HERMES_ENV_HOME/auth.json" /home/emiller/.codex/auth.json; then
                  mv "$HERMES_ENV_HOME/auth.json" "$HERMES_ENV_HOME/auth.json.shared-seed-disabled"
                fi
                if [ -e "$HERMES_ENV_HOME/.codex" ] || [ -L "$HERMES_ENV_HOME/.codex" ]; then
                  rm -rf "$HERMES_ENV_HOME/.codex"
                fi
                ln -s "$BETTY_HOME/.codex" "$HERMES_ENV_HOME/.codex"
                chown -h emiller:users "$HERMES_ENV_HOME/.codex"
                ln -sfn /home/emiller/obsidian-vault "$HERMES_ENV_HOME/workspace/repos/obsidian-vault"
                chown -h emiller:users "$HERMES_ENV_HOME/workspace/repos/obsidian-vault"
                ln -sfn /home/emiller/obsidian-vault "$BETTY_HOME/obsidian-vault"
                chown -h emiller:users "$BETTY_HOME/obsidian-vault"

                mkdir -p "$ENV_DIR"
                : > "$ENV_TMP"
                chmod 600 "$ENV_TMP"

                printf 'HERMES_HONCHO_HOST=%s\n' "betty" >> "$ENV_TMP"

                ${lib.concatMapStringsSep "\n" (secret: ''
                  if [ -f ${lib.escapeShellArg (toString secret.path)} ]; then
                    secret_value="$(cat ${lib.escapeShellArg (toString secret.path)})"
                    printf '%s=%s\n' ${lib.escapeShellArg secret.envVar} "$secret_value" >> "$ENV_TMP"
                  fi
                '') hermesBettySecrets}

                export OP_SERVICE_ACCOUNT_TOKEN="$(cat /etc/opnix-token)"
                ${lib.concatStringsSep "\n" (
                  lib.mapAttrsToList (envVar: reference: ''
                    secret_value="$(${op} read ${lib.escapeShellArg reference})"
                    printf '%s=%s\n' ${lib.escapeShellArg envVar} "$secret_value" >> "$ENV_TMP"
                  '') hermesBetty1PasswordReferences
                )}
                unset secret_value OP_SERVICE_ACCOUNT_TOKEN

                # Music Assistant WS token lives in HA config entry data (not agenix).
                # Betty DJ verifier needs it to list queue items and match receipt URIs.
                ${pkgs.python3}/bin/python3 - "$ENV_TMP" <<'PY'
        import json
        import sys
        from pathlib import Path

        env_tmp = Path(sys.argv[1])
        entries_path = Path("/var/lib/hass/.storage/core.config_entries")
        if not entries_path.is_file():
            raise SystemExit(0)
        data = json.loads(entries_path.read_text())
        entries = data.get("data", {}).get("entries", data.get("data", []))
        if isinstance(entries, dict):
            entries = list(entries.values())
        token = None
        url = None
        for entry in entries:
            if entry.get("domain") != "music_assistant":
                continue
            payload = entry.get("data") or {}
            token = (payload.get("token") or "").strip() or None
            url = (payload.get("url") or "").strip() or None
            if token:
                break
        if not token:
            raise SystemExit(0)
        with env_tmp.open("a", encoding="utf-8") as fh:
            fh.write(f"MUSIC_ASSISTANT_TOKEN={token}\n")
            if url:
                fh.write(f"MUSIC_ASSISTANT_URL={url}\n")
        PY

                chown emiller:users "$ENV_TMP"
                mv -f "$ENV_TMP" "$ENV_FILE"
                trap - EXIT
      '';
    };

    hermesOrchestratorSecretsMaterialize = {
      deps = [
        "agenixInstall"
        "agenixChown"
      ];
      text = ''
        ORCHESTRATOR_HOME="/var/lib/hermes-orchestrator"
        ENV_DIR="/run/hermes-orchestrator-env"
        ENV_FILE="$ENV_DIR/secrets.env"
        HERMES_ENV_HOME="$ORCHESTRATOR_HOME/.hermes"

        install -d -o emiller -g users -m 0750 "$ORCHESTRATOR_HOME"
        install -d -o emiller -g users -m 0750 "$HERMES_ENV_HOME"
        install -d -o emiller -g users -m 0750 "$HERMES_ENV_HOME/.codex"
        install -d -o emiller -g users -m 0750 "$HERMES_ENV_HOME/workspace"
        install -d -o emiller -g users -m 0750 "$HERMES_ENV_HOME/workspace/repos"
        install -d -o emiller -g users -m 0750 "$ORCHESTRATOR_HOME/.codex"
        install -d -o emiller -g users -m 0750 "$ORCHESTRATOR_HOME/.local"
        install -d -o emiller -g users -m 0750 "$ORCHESTRATOR_HOME/.local/bin"
        install -d -o emiller -g users -m 0750 "$ORCHESTRATOR_HOME/.local/state"
        install -d -o emiller -g users -m 0750 "$ORCHESTRATOR_HOME/.local/state/hermes"
        install -d -o emiller -g users -m 0750 "$ORCHESTRATOR_HOME/.local/state/hermes/gateway-locks"

        ln -sfn /home/emiller/.codex/auth.json "$ORCHESTRATOR_HOME/.codex/auth.json"
        chown -h emiller:users "$ORCHESTRATOR_HOME/.codex/auth.json"
        ln -sfn /home/emiller/.codex/auth.json "$HERMES_ENV_HOME/.codex/auth.json"
        chown -h emiller:users "$HERMES_ENV_HOME/.codex/auth.json"
        ln -sfn /home/emiller/obsidian-vault "$HERMES_ENV_HOME/workspace/repos/obsidian-vault"
        chown -h emiller:users "$HERMES_ENV_HOME/workspace/repos/obsidian-vault"
        ln -sfn ${tnoteBaseRepo} "$HERMES_ENV_HOME/workspace/repos/tnote"
        chown -h emiller:users "$HERMES_ENV_HOME/workspace/repos/tnote"
        ln -sfn ${pkgs.my.tnote}/bin/tnote "$ORCHESTRATOR_HOME/.local/bin/tnote"
        chown -h emiller:users "$ORCHESTRATOR_HOME/.local/bin/tnote"

        mkdir -p "$ENV_DIR"
        : > "$ENV_FILE"
        chmod 600 "$ENV_FILE"
        chown emiller:users "$ENV_FILE"

        printf 'HERMES_HONCHO_HOST=%s\n' "orchestrator" >> "$ENV_FILE"

        ${lib.concatMapStringsSep "\n" (secret: ''
          if [ -f ${lib.escapeShellArg (toString secret.path)} ]; then
            secret_value="$(cat ${lib.escapeShellArg (toString secret.path)})"
            printf '%s=%s\n' ${lib.escapeShellArg secret.envVar} "$secret_value" >> "$ENV_FILE"
          fi
        '') hermesOrchestratorSecrets}
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
        install -d -o root -g root -m 0755 /repos
        ln -sfn /home/emiller/obsidian-vault /repos/obsidian-vault
        chown -h emiller:users /repos/obsidian-vault

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

        if [ -f /etc/opnix-token ]; then
          OP_SERVICE_ACCOUNT_TOKEN="$(cat /etc/opnix-token)"
          export OP_SERVICE_ACCOUNT_TOKEN
          if radar_openrouter_key="$(${pkgs._1password-cli}/bin/op read 'op://Agents/Radar Flue Openrouter/credential' 2>/dev/null)" && [ -n "$radar_openrouter_key" ]; then
            printf 'OPENROUTER_API_KEY=%s\n' "$radar_openrouter_key" >> "$ENV_FILE"
          fi
          unset radar_openrouter_key OP_SERVICE_ACCOUNT_TOKEN
        fi

        printf 'TELEGRAM_ALLOWED_USERS=%s\n' '8357890648' >> "$ENV_FILE"
      '';
    };

    hermesBettyWorkspaceCompat = {
      deps = [ ];
      text = ''
        BETTY_HOME="/var/lib/hermes-betty"

        install -d -o emiller -g users -m 0750 "$BETTY_HOME/.local/bin"
        install -d -o emiller -g users -m 0750 "$BETTY_HOME/home/emiller"

        ln -sfn ${pkgs.my.tnote}/bin/tnote "$BETTY_HOME/.local/bin/tnote"
        ln -sfn /home/emiller/obsidian-vault "$BETTY_HOME/obsidian-vault"
        ln -sfn ${millDocsVaultPath} "$BETTY_HOME/home/emiller/mill-docs"

        chown -h emiller:users "$BETTY_HOME/.local/bin/tnote"
        chown -h emiller:users "$BETTY_HOME/obsidian-vault"
        chown -h emiller:users "$BETTY_HOME/home/emiller/mill-docs"
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
    bettyBookPlayer
    nixPrivateGithub
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
    bun # For pi CLI backend (npm: @mariozechner/pi-coding-agent)
    prek # Agent quality-gate runner used by vault/repo AGENTS instructions
    uv # For vault sync scripts (PEP 723 inline deps)
    home-assistant-cli # hass-cli: agent-friendly HA REST API wrapper
    himalaya # IMAP/SMTP CLI for Fastmail triage by Scintillate/agents
    inputs.nix-steipete-tools.packages.${hostSystem}.sag # TTS runtime support
    hermesRuntimeSmoke
    radarBlogwatcherCli # Radar terminal login-shell runtime
    rtk # Hermes terminal command rewriting after login-shell snapshot
    qmd # thin wrapper around llm-agents.nix qmd forcing CPU mode on this NUC
    my.zele # packaged upstream+patches zele CLI
    my.tnote # packaged TaskNotes CLI; no boot-time mutable checkout/bun install
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
        environment = {
          CODEX_HOME = lib.mkForce "/home/emiller/.codex";
          HERMES_KANBAN_HOME = hermesSharedHome;
        };
        hostPathMounts = lib.mkForce {
          "${hermesSharedHome}" = hermesSharedHome;
          "/home/emiller/.codex" = "/home/emiller/.codex";
          "/home/emiller/mill-docs" = "/repos/mill-docs";
          "/home/emiller/obsidian-vault" = "/repos/obsidian-vault";
        };
        environmentFiles = [ "/run/hermes-anne-env/secrets.env" ];
      };
      betty = {
        # Betty is Codex-backed, but must own her mutable OAuth state. Do not
        # seed or mount /home/emiller/.codex/auth.json; bootstrap Betty's
        # profile-owned login under /var/lib/hermes-betty instead.
        workingDirectory = "/repos/mill-docs";
        extraPackages = [ bettyBookPlayer ];
        environment = {
          CODEX_HOME = lib.mkForce "/data/.codex";
          HERMES_KANBAN_HOME = hermesSharedHome;
        };
        hostPathMounts = lib.mkForce {
          "${hermesSharedHome}" = hermesSharedHome;
          "/home/emiller/mill-docs" = "/repos/mill-docs";
          "/home/emiller/obsidian-vault" = "/repos/obsidian-vault";
          "${tnoteBaseRepo}" = "/repos/tnote";
        };
        environmentFiles = [ "/run/hermes-betty-env/secrets.env" ];
      };
      scintillate = {
        # Codex OAuth refresh tokens are single-use. Do not seed Hermes from
        # ~/.codex/auth.json or share Codex CLI credentials; Scintillate owns
        # its Codex login in /var/lib/hermes-scintillate/.hermes/auth.json.
        extraPackages = with pkgs; [
          bun
          nix
          nodejs
          openssh
          pnpm
          prek
          himalaya
          whisper-cpp
          rtk
        ];
        settings = {
          stt.provider = "local_command";
        };
        environment = {
          HERMES_KANBAN_HOME = hermesSharedHome;
          HERMES_LOCAL_STT_COMMAND = "${pkgs.whisper-cpp}/bin/whisper-cli -m ${scintillateWhisperModel} -f {input_path} --language {language} --output-txt --output-file {output_dir}/transcript --no-timestamps --no-prints";
          PYTHONPATH = hermesTelegramPythonPath;
        };
        hostPathMounts = {
          "${hermesSharedHome}" = hermesSharedHome;
          "/home/emiller/.ssh" = "/home/ubuntu/.ssh";
        };
        environmentFiles = [ "/run/hermes-scintillate-env/secrets.env" ];
      };
      amosburton = {
        authFile = "/home/emiller/.codex/auth.json";
        environment = {
          CODEX_HOME = lib.mkForce "/home/emiller/.codex";
          HERMES_KANBAN_HOME = hermesSharedHome;
        };
        hostPathMounts = lib.mkForce {
          "${hermesSharedHome}" = hermesSharedHome;
          "/home/emiller/.codex" = "/home/emiller/.codex";
          "/home/emiller/.config/dotfiles" = "/repos/dotfiles";
          "/home/emiller/obsidian-vault" = "/repos/obsidian-vault";
          "/home/emiller/src/personal/agents-workspace" = "/repos/agents-workspace";
          "/home/emiller/src/personal/finances" = "/repos/finances";
          "/home/emiller/src/personal/tailnet" = "/repos/tailnet";
        };
        environmentFiles = [ "/run/hermes-amosburton-env/secrets.env" ];
      };
      orchestrator = {
        stateDir = "/var/lib/hermes-orchestrator";
        workingDirectory = "/var/lib/hermes-orchestrator/workspace";
        authFile = "/home/emiller/.codex/auth.json";
        environment = {
          CODEX_HOME = lib.mkForce "/home/emiller/.codex";
          HERMES_KANBAN_HOME = hermesSharedHome;
        };
        hostPathMounts = lib.mkForce {
          "${hermesSharedHome}" = hermesSharedHome;
          "/home/emiller/.codex" = "/home/emiller/.codex";
          "/home/emiller/obsidian-vault" = "/repos/obsidian-vault";
          "${tnoteBaseRepo}" = "/repos/tnote";
        };
        environmentFiles = [ "/run/hermes-orchestrator-env/secrets.env" ];
      };
    };
  };

  systemd.services.hermes-gateway-orchestrator.serviceConfig.ExecStartPre = lib.mkBefore [
    (pkgs.writeShellScript "hermes-orchestrator-profile-list-mirror" ''
      set -eu
      profiles_dir=/var/lib/hermes-orchestrator/.hermes/profiles
      rm -rf "$profiles_dir"
      install -d -o emiller -g users -m 0750 "$profiles_dir"

      for profile in amosburton anne betty orchestrator scintillate; do
        src=/var/lib/hermes-$profile/.hermes
        dst=$profiles_dir/$profile
        if [ -d "$src" ]; then
          install -d -o emiller -g users -m 0750 "$dst"
          [ -f "$src/config.yaml" ] && install -o emiller -g users -m 0640 "$src/config.yaml" "$dst/config.yaml"
          [ -f "$src/profile.yaml" ] && install -o emiller -g users -m 0640 "$src/profile.yaml" "$dst/profile.yaml"
        fi
      done
    '')
  ];
  systemd.services.hermes-gateway-orchestrator.enable = false;

  systemd.services.hermes-gateway-anne.serviceConfig = {
    ExecStartPre = lib.mkBefore [
      (pkgs.writeShellScript "hermes-anne-repo-compat-links" ''
        set -eu
        install -d -o emiller -g users -m 0750 /var/lib/hermes-anne/home/repos
        ln -sfn /repos/mill-docs /var/lib/hermes-anne/home/repos/mill-docs
        ln -sfn /repos/obsidian-vault /var/lib/hermes-anne/home/repos/obsidian-vault
        chown -h emiller:users /var/lib/hermes-anne/home/repos/mill-docs /var/lib/hermes-anne/home/repos/obsidian-vault
      '')
      "${pkgs.coreutils}/bin/test -f /home/emiller/.codex/auth.json"
      "${pkgs.coreutils}/bin/test -f /var/lib/hermes-anne/.codex/auth.json"
    ];
  };
  systemd.services.hermes-gateway-anne.enable = false;

  systemd.services.hermes-gateway-betty.serviceConfig.ExecStartPre = lib.mkBefore [
    (pkgs.writeShellScript "hermes-betty-repo-compat-links" ''
      set -eu
      install -d -o emiller -g users -m 0750 /var/lib/hermes-betty/home/repos
      ln -sfn /repos/mill-docs /var/lib/hermes-betty/home/repos/mill-docs
      ln -sfn /repos/obsidian-vault /var/lib/hermes-betty/home/repos/obsidian-vault
      ln -sfn /repos/tnote /var/lib/hermes-betty/home/repos/tnote
      chown -h emiller:users /var/lib/hermes-betty/home/repos/mill-docs /var/lib/hermes-betty/home/repos/obsidian-vault /var/lib/hermes-betty/home/repos/tnote
    '')
  ];
  systemd.services.hermes-gateway-betty.enable = false;

  systemd.services.hermes-gateway-amosburton.serviceConfig.ExecStartPre = lib.mkBefore [
    (pkgs.writeShellScript "hermes-amosburton-repo-compat-links" ''
      set -eu
      install -d -o emiller -g users -m 0750 /var/lib/hermes-amosburton/home/repos
      ln -sfn /repos/agents-workspace /var/lib/hermes-amosburton/home/repos/agents-workspace
      ln -sfn /repos/dotfiles /var/lib/hermes-amosburton/home/repos/dotfiles
      ln -sfn /repos/finances /var/lib/hermes-amosburton/home/repos/finances
      ln -sfn /repos/obsidian-vault /var/lib/hermes-amosburton/home/repos/obsidian-vault
      ln -sfn /repos/tailnet /var/lib/hermes-amosburton/home/repos/tailnet
      chown -h emiller:users /var/lib/hermes-amosburton/home/repos/*
    '')
  ];
  systemd.services.hermes-gateway-amosburton.enable = false;

  systemd.services.hermes-gateway-scintillate = {
    enable = false;
    # Scintillate is an interactive Telegram gateway.  A routine NixOS
    # auto-upgrade/switch should not SIGTERM it mid-turn and send
    # "Gateway shutting down -- Your current task will be interrupted".
    # Apply unit/package changes on the next explicit service restart instead.
    restartIfChanged = false;
    after = [ "opnix-secrets.service" ];
    wants = [ "opnix-secrets.service" ];
    serviceConfig.ExecStartPre = lib.mkAfter [
      himalayaFastmailSetupScript
      (pkgs.writeShellScript "hermes-scintillate-telegram-dotenv" ''
        set -eu
        env_file=/var/lib/hermes-scintillate/.hermes/.env
        secrets_file=/run/hermes-scintillate-env/secrets.env
        tmp_file="$env_file.tmp.$$"

        install -d -o emiller -g users -m 0750 "$(dirname "$env_file")"
        touch "$env_file"
        chown emiller:users "$env_file"
        chmod 0600 "$env_file"

        grep -v '^TELEGRAM_' "$env_file" > "$tmp_file"
        grep '^TELEGRAM_' "$secrets_file" >> "$tmp_file"
        install -o emiller -g users -m 0600 "$tmp_file" "$env_file"
        rm -f "$tmp_file"
      '')
    ];
  };

  # Music Assistant player protocols allocate dynamic ports and require an
  # unrestricted local interface; eno1 is the NUC's private home LAN.
  networking.firewall.trustedInterfaces = [ "eno1" ];

  networking.firewall.interfaces.tailscale0.allowedTCPPorts = [
    hermesScintillateWebuiPort
    hermesScintillateDesktopDashboardPort
  ];

  systemd.services.hermes-scintillate-desktop-dashboard = {
    enable = false;
    description = "Hermes Desktop-compatible dashboard for Scintillate";
    wantedBy = [ "multi-user.target" ];
    after = [
      "hermes-gateway-scintillate.service"
      "network-online.target"
    ];
    wants = [
      "hermes-gateway-scintillate.service"
      "network-online.target"
    ];
    path = [
      hermesAgentBase
      pkgs.bash
      pkgs.coreutils
    ];
    environment = {
      HOME = hermesSharedStateDir;
      HERMES_BASE_HOME = hermesSharedHome;
      HERMES_HOME = hermesSharedHome;
      # The shared Hermes home is container-aware for the host CLI. This service
      # intentionally runs the host dashboard process directly so Hermes Desktop
      # can use the dashboard JSON-RPC/WebSocket API from macOS.
      HERMES_DEV = "1";
    };
    serviceConfig = {
      User = "emiller";
      Group = "users";
      WorkingDirectory = hermesSharedStateDir;
      Restart = "always";
      RestartSec = 5;
      EnvironmentFile = [ "/run/hermes-scintillate-env/secrets.env" ];
      ExecStart = pkgs.writeShellScript "hermes-scintillate-desktop-dashboard-start" ''
        set -eu
        export HERMES_DASHBOARD_SESSION_TOKEN="$API_SERVER_KEY"
        exec ${hermesAgentBase}/bin/hermes dashboard \
          --host 0.0.0.0 \
          --port ${toString hermesScintillateDesktopDashboardPort} \
          --no-open \
          --skip-build \
          --insecure
      '';
      NoNewPrivileges = true;
      ProtectHome = false;
      ProtectSystem = "strict";
      PrivateTmp = true;
      ReadWritePaths = [
        hermesSharedStateDir
        "/var/lib/hermes-amosburton"
        "/var/lib/hermes-anne"
        "/var/lib/hermes-betty"
        "/var/lib/hermes-radar"
        "/var/lib/hermes-scintillate"
      ];
    };
  };

  systemd.services.hermes-scintillate-webui = {
    enable = false;
    description = "Hermes WebUI for Scintillate";
    wantedBy = [ "multi-user.target" ];
    after = [
      "hermes-gateway-scintillate.service"
      "network-online.target"
    ];
    wants = [
      "hermes-gateway-scintillate.service"
      "network-online.target"
    ];
    path = [
      hermesAgentBase
      hermesWebuiPython
      pkgs.bash
      pkgs.coreutils
      pkgs.git
    ];
    environment = {
      HOME = hermesSharedStateDir;
      HERMES_BASE_HOME = hermesSharedHome;
      HERMES_HOME = hermesSharedHome;
      HERMES_KANBAN_HOME = hermesSharedHome;
      HERMES_WEBUI_AGENT_DIR = hermesPythonSitePackages;
      HERMES_WEBUI_CHAT_BACKEND = "gateway";
      HERMES_WEBUI_GATEWAY_BASE_URL = "http://127.0.0.1:${toString hermesScintillateApiServerPort}";
      HERMES_WEBUI_HOST = "127.0.0.1";
      HERMES_WEBUI_PORT = toString hermesScintillateWebuiPort;
      HERMES_WEBUI_STATE_DIR = "${hermesSharedHome}/webui";
      PYTHONPATH = "${hermesPythonSitePackages}:${hermesWebuiSource}";
    };
    serviceConfig = {
      User = "emiller";
      Group = "users";
      WorkingDirectory = hermesWebuiSource;
      Restart = "always";
      RestartSec = 5;
      EnvironmentFile = [ "/run/hermes-scintillate-env/secrets.env" ];
      ExecStart = pkgs.writeShellScript "hermes-scintillate-webui-start" ''
        set -eu
        export HERMES_WEBUI_GATEWAY_API_KEY="$API_SERVER_KEY"
        export HERMES_WEBUI_PASSWORD="$(printf %s "$API_SERVER_KEY" | ${pkgs.coreutils}/bin/sha256sum | ${pkgs.coreutils}/bin/cut -c1-32)"
        exec ${hermesWebuiPython}/bin/python ${hermesWebuiSource}/server.py
      '';
      NoNewPrivileges = true;
      ProtectHome = false;
      ProtectSystem = "strict";
      PrivateTmp = true;
      ReadWritePaths = [
        hermesSharedStateDir
        "/var/lib/hermes-amosburton"
        "/var/lib/hermes-anne"
        "/var/lib/hermes-betty"
        "/var/lib/hermes-radar"
        "/var/lib/hermes-scintillate"
      ];
    };
  };

  systemd.services.hermes-scintillate-tailscale-serve = {
    enable = false;
    description = "Expose Scintillate Hermes WebUI via Tailscale Service";
    wantedBy = [ "multi-user.target" ];
    after = [
      "hermes-scintillate-webui.service"
      "tailscaled.service"
    ];
    wants = [
      "hermes-scintillate-webui.service"
      "tailscaled.service"
    ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = "${pkgs.bash}/bin/bash -c '${pkgs.util-linux}/bin/flock /run/tailscale-serve.lock ${pkgs.bash}/bin/bash -c \"for i in \\$(seq 1 15); do ${pkgs.tailscale}/bin/tailscale serve --bg --service=svc:${hermesScintillateTailscaleServiceName} --https=443 http://127.0.0.1:${toString hermesScintillateWebuiPort} && exit 0; sleep 1; done; exit 1\"'";
      ExecStop = "${pkgs.bash}/bin/bash -c '${pkgs.tailscale}/bin/tailscale serve clear svc:${hermesScintillateTailscaleServiceName} || true'";
    };
  };

  systemd.services.mill-docs-agents-tailscale-serve = {
    description = "Expose Mill docs agents via Tailscale Service";
    wantedBy = [ "multi-user.target" ];
    after = [
      "tailscaled.service"
    ];
    wants = [
      "tailscaled.service"
    ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = "${pkgs.bash}/bin/bash -c '${pkgs.util-linux}/bin/flock /run/tailscale-serve.lock ${pkgs.bash}/bin/bash -c \"for i in \\$(seq 1 15); do ${pkgs.tailscale}/bin/tailscale serve --bg --service=svc:mill-docs-agents --https=443 http://127.0.0.1:8788 && exit 0; sleep 1; done; exit 1\"'";
      ExecStop = "${pkgs.bash}/bin/bash -c '${pkgs.tailscale}/bin/tailscale serve clear svc:mill-docs-agents || true'";
    };
  };

  systemd.services.hermes-amosburton-cron-tick = {
    description = "Run Amos Burton cron jobs without an interactive gateway";
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    path = [
      amosburtonHermesLauncher
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
      SupplementaryGroups = [ "onepassword-secrets" ];
      WorkingDirectory = "/var/lib/hermes-amosburton";
      EnvironmentFile = [ "/run/hermes-amosburton-env/secrets.env" ];
      Environment = [
        "HOME=/var/lib/hermes-amosburton"
        "HERMES_HOME=/var/lib/hermes-amosburton/.hermes"
        "HERMES_KANBAN_HOME=${hermesSharedHome}"
        "HERMES_PROFILE=amosburton"
        "CODEX_HOME=/home/emiller/.codex"
      ];
      ExecStart = "${amosburtonCronExecutor}";
      NoNewPrivileges = true;
      PrivateTmp = true;
      ProtectHome = false;
      ProtectSystem = "strict";
      ReadWritePaths = [
        hermesSharedStateDir
        "/var/lib/hermes-amosburton"
        "/home/emiller/.config/dotfiles"
        "/home/emiller/src/personal/agents-workspace"
        "/home/emiller/src/personal/finances"
        "/home/emiller/src/personal/tailnet"
      ];
    };
  };

  systemd.timers.hermes-amosburton-cron-tick = {
    description = "Run Amos Burton background cron jobs on a timer";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = "2min";
      OnUnitActiveSec = "5min";
      RandomizedDelaySec = "30s";
      Unit = "hermes-amosburton-cron-tick.service";
    };
  };

  systemd.services.hermes-betty-cron-tick = {
    description = "Run Betty cron jobs without an interactive gateway";
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    path = [
      bettyHermesLauncher
      bettyBookPlayer
      hermesAgentBase
      inputs.agents-workspace.packages.${hostSystem}.gws
      pkgs._1password-cli
      pkgs.bashInteractive
      pkgs.coreutils
      pkgs.findutils
      pkgs.git
      pkgs.himalaya
      pkgs.python3
      pkgs.uv
    ];
    serviceConfig = {
      Type = "oneshot";
      User = "emiller";
      Group = "users";
      SupplementaryGroups = [ "onepassword-secrets" ];
      WorkingDirectory = "/var/lib/hermes-betty";
      EnvironmentFile = [ "/run/hermes-betty-env/secrets.env" ];
      Environment = [
        "HOME=/var/lib/hermes-betty"
        "HERMES_HOME=/var/lib/hermes-betty/.hermes"
        "HERMES_KANBAN_HOME=${hermesSharedHome}"
        "HERMES_PROFILE=betty"
        "MESSAGING_CWD=/repos/mill-docs"
        "CODEX_HOME=/var/lib/hermes-betty/.codex"
        "DISCORD_HOME_CHANNEL=${toString bettyDiscordBindings.homeChannelId}"
      ];
      ExecStart = "${pkgs.util-linux}/bin/flock /var/lib/hermes-betty/.profile.lock ${bettyHermesCronExecutor}";
      NoNewPrivileges = true;
      PrivateTmp = true;
      ProtectHome = false;
      ProtectSystem = "strict";
      ReadWritePaths = [
        hermesSharedStateDir
        "/var/lib/hermes-betty"
        "/home/emiller/mill-docs"
      ];
    };
  };

  systemd.services.hermes-betty-good-morning-dj = {
    description = "Have Betty start and curate the Good Morning playlist";
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    path = [
      bettyHermesLauncher
      hermesAgentBase
      pkgs.bashInteractive
      pkgs.coreutils
      pkgs.curl
      pkgs.home-assistant-cli
      pkgs.jq
      pkgs.python3
    ];
    serviceConfig = {
      Type = "oneshot";
      User = "emiller";
      Group = "users";
      SupplementaryGroups = [ "onepassword-secrets" ];
      WorkingDirectory = "/var/lib/hermes-betty";
      EnvironmentFile = [ "/run/hermes-betty-env/secrets.env" ];
      Environment = [
        "HOME=/var/lib/hermes-betty"
        "HERMES_HOME=/var/lib/hermes-betty/.hermes"
        "HERMES_KANBAN_HOME=${hermesSharedHome}"
        "HERMES_PROFILE=betty"
        "MESSAGING_CWD=/repos/mill-docs"
        "CODEX_HOME=/var/lib/hermes-betty/.codex"
        # Built-in ha_* tools read HASS_URL; default homeassistant.local fails on NUC.
        "HASS_URL=http://127.0.0.1:8123"
        "HA_URL=http://127.0.0.1:8123"
        # Verifier prefers loopback even when HA stores the LAN URL.
        "MUSIC_ASSISTANT_URL=http://127.0.0.1:8095"
      ];
      ExecStart = "${pkgs.util-linux}/bin/flock /var/lib/hermes-betty/.profile.lock ${bettyGoodMorningDjExecutor}";
      NoNewPrivileges = true;
      PrivateTmp = true;
      ProtectHome = false;
      ProtectSystem = "strict";
      ReadWritePaths = [
        hermesSharedStateDir
        "/var/lib/hermes-betty"
      ];
    };
  };

  security.sudo.extraRules = [
    {
      users = [ "hass" ];
      commands = [
        {
          command = "${pkgs.systemd}/bin/systemctl start --no-block hermes-betty-good-morning-dj.service";
          options = [ "NOPASSWD" ];
        }
      ];
    }
  ];

  systemd.timers.hermes-betty-cron-tick = {
    description = "Run Betty background cron jobs on a timer";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = "2min";
      OnUnitActiveSec = "5min";
      RandomizedDelaySec = "30s";
      Unit = "hermes-betty-cron-tick.service";
    };
  };

  systemd.services.hermes-radar-cron-tick = {
    description = "Run Radar cron jobs without an interactive gateway";
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    path = [
      radarHermesLauncher
      radarBlogwatcherCli
      hermesAgentBase
      pkgs.bashInteractive
      pkgs.coreutils
      pkgs.findutils
      pkgs.git
      pkgs.python3
      pkgs.rtk
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
        "HERMES_KANBAN_HOME=${hermesSharedHome}"
        "HERMES_PROFILE=radar"
        "MESSAGING_CWD=/var/lib/hermes-radar/.hermes/workspace"
        "CODEX_HOME=/home/emiller/.codex"
        "EMAIL_ADDRESS=norbot@agentmail.to"
        "EMAIL_IMAP_HOST=imap.agentmail.to"
        "EMAIL_IMAP_PORT=993"
        "EMAIL_SMTP_HOST=smtp.agentmail.to"
        "EMAIL_SMTP_PORT=587"
        "EMAIL_HOME_ADDRESS=emiller@edmundmiller.dev"
      ];
      ExecStartPre = [ "+${pkgs.coreutils}/bin/chown -hR emiller:users /var/lib/hermes-radar" ];
      ExecStart = "${radarHermesLauncher}/bin/radar-hermes cron tick";
      NoNewPrivileges = true;
      PrivateTmp = true;
      ProtectHome = false;
      ProtectSystem = "strict";
      ReadWritePaths = [
        hermesSharedStateDir
        "/var/lib/hermes-radar"
      ];
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

  systemd.services.hermes-scintillate-cron-tick = {
    description = "Run Scintillate cron jobs without an interactive gateway";
    after = [
      "network-online.target"
      "opnix-secrets.service"
    ];
    wants = [
      "network-online.target"
      "opnix-secrets.service"
    ];
    path = [
      hermesAgentBase
      pkgs.bashInteractive
      pkgs.coreutils
      pkgs.findutils
      pkgs.git-lfs
      pkgs.python3
    ]
    ++ config.services.hermes-agent.profiles.scintillate.extraPackages;
    environment = config.services.hermes-agent.profiles.scintillate.environment // {
      HOME = "/var/lib/hermes-scintillate";
      HERMES_HOME = "/var/lib/hermes-scintillate/.hermes";
      HERMES_REAL_HOME = "/var/lib/hermes-scintillate";
      HERMES_KANBAN_HOME = hermesSharedHome;
      HERMES_PROFILE = "scintillate";
      TERMINAL_HOME_MODE = "real";
      MESSAGING_CWD = "/home/hermes/repos/obsidian-vault";
      CODEX_HOME = "/home/emiller/.codex";
    };
    serviceConfig = {
      Type = "oneshot";
      User = "emiller";
      Group = "users";
      WorkingDirectory = "/home/hermes/repos/obsidian-vault";
      EnvironmentFile = [ "/run/hermes-scintillate-env/secrets.env" ];
      ExecStart = "${hermesAgentBase}/bin/hermes cron tick";
      NoNewPrivileges = true;
      PrivateTmp = true;
      ProtectHome = false;
      ProtectSystem = "strict";
      ReadWritePaths = [
        hermesSharedStateDir
        "/var/lib/hermes-scintillate"
        "/home/hermes/repos/obsidian-vault"
        "/home/emiller/obsidian-vault"
        tnoteBaseRepo
      ];
    };
  };

  systemd.timers.hermes-scintillate-cron-tick = {
    description = "Run Scintillate background cron jobs on a timer";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = "2min";
      OnUnitActiveSec = "5min";
      RandomizedDelaySec = "30s";
      Unit = "hermes-scintillate-cron-tick.service";
    };
  };

  systemd.services.hermes-gateway-betty.serviceConfig.ReadWritePaths = [
    "/var/lib/hermes-betty"
    "/home/emiller/mill-docs"
  ];

  systemd.services.hermes-runtime-smoke = {
    enable = false;
    description = "Run read-only Hermes runtime smoke checks";
    after = [ "docker.service" ] ++ hermesGatewayUnits;
    wants = [ "docker.service" ];
    serviceConfig = {
      Type = "oneshot";
      TimeoutStartSec = "15min";
      ExecStart = "${hermesRuntimeSmoke}/bin/hermes-runtime-smoke";
    };
  };

  # Keep NUC on an LTS kernel for ZFS. nixos-unstable's default
  # linuxPackages currently tracks 7.0.x, where zfs-kernel-2.4.1 is marked
  # broken and blocks evaluation before deploy activation.
  boot.kernelPackages = lib.mkForce pkgs.linuxPackages_6_12;

  # NUC root pool imports cleanly by default; make the upstream default explicit
  # to silence the NixOS ZFS force-import warning.
  boot.zfs.forceImportRoot = false;

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
      amoxide.enable = true;
      agentBrowser.enable = true;
      git = {
        enable = true;
        # Temporarily disabled on NUC: package build currently fails in npm deps
        # with `node: command not found`, blocking nixos-rebuild.
        stack.enable = false;
      };
      tmux.enable = true;
      zsh.enable = true;
      herdr.enable = true;
    };
    agents = {
      codex.enable = true;
      omp.enable = true;
      opencode.enable = true;
      pi.enable = true;
    };
    services = {
      audiobookshelf = {
        enable = true;
        tailscaleService.enable = true;
      };
      agentsview = {
        enable = true;
        tailscaleService.enable = true;
      };
      hermes = {
        enable = true;
        agentSkillBundles = [
          config.home-manager.users.${config.user.name}.programs.dotfiles-agent-skills.bundles.hermes
        ];
        # Containers use host networking, so prefer the deployment-local HA
        # endpoint over mDNS names such as homeassistant.local from inside
        # Hermes gateway processes.
        homeAssistantUrl = "http://127.0.0.1:8123";
        agents = {
          scintillate = {
            providers = {
              obsidianVault.hostPath = "/home/emiller/obsidian-vault";
              tnote = {
                package = pkgs.my.tnote;
                repoPath = tnoteBaseRepo;
              };
            };
            mcpBearerTokenPaths.linear = config.age.secrets.scintillate-linear-mcp-token.path;
          };

          betty = {
            workspaceLinks."repos/mill-docs" = "/home/emiller/mill-docs";
            workspaceLinks."repos/obsidian-vault" = "/home/emiller/obsidian-vault";
            workspaceLinks."repos/tnote" = tnoteBaseRepo;
          };
          anne = { };
          orchestrator = {
            providers = {
              obsidianVault.hostPath = "/home/emiller/obsidian-vault";
              tnote = {
                package = pkgs.my.tnote;
                repoPath = tnoteBaseRepo;
              };
            };
          };
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
      music-assistant = {
        enable = true;
        tailscaleService.enable = true;
      };
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
          "reolink" # Reolink cameras/NVR/Home Hub (config-flow: set up via UI)
          "samsungtv" # Samsung TV integration
          "cast" # Chromecast/Google Cast
          "nanoleaf" # Nanoleaf lights used by HA scenes
          "mobile_app" # HA Companion app (iOS/Android)
          "bluetooth" # BLE device discovery
          "spotify" # Spotify playback control (config-flow: add via UI after deploy)
          "music_assistant" # Music Assistant server/player bridge (config-flow: add via UI after deploy)
          "elevenlabs" # ElevenLabs TTS/STT (config-flow: add API key via UI)
          "zha" # Zigbee Home Automation via ZBT-2 dongle
          "thread" # Thread border router via ZBT-2 dongle
          "otbr" # OpenThread Border Router (ZBT-2 Thread radio)
          "xiaomi_miio" # Xiaomi air purifier (zhimi.airpurifier.mb3 x2)
          "mcp_server" # MCP server (config-flow: add via UI after deploy)
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
        healthchecks.readonlyApiKeyFile = config.age.secrets.healthchecks-api-key-readonly.path;
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
      homebox = {
        enable = true;
        allowRegistration = false;
        environmentFile = config.age.secrets.homebox-env.path;
        tailscaleService.enable = true;
      };
      jellyfin = {
        enable = true;
        tailscaleService.enable = true;
      };
      lubelogger = {
        enable = true;
        environmentFile = config.age.secrets.lubelogger-env.path;
      };
      latitude = {
        enable = true;
        environmentFile = config.age.secrets.latitude-env.path;
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
      moshi = {
        enable = true;
        hookSecretsFile = config.age.secrets.moshi-hook-secrets-json.path;
      };
      ssh.enable = true;
      syncthing.enable = false;
      tailscale.enable = true;
      obsidian-sync = {
        enable = true;
        mode = "desktop"; # bidirectional — agents edit vault files on NUC
        vaultName = "llm-wiki";
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
      opencode.enable = false;
      kittylitter = {
        enable = true;
        enabledAgents = [
          "pi"
          "hermes"
          "droid"
        ];
      };

      open-wearables = {
        enable = true;
        # API only for now (historical Apple XML import + agent access)
        enableFrontend = false;
      };

      transmission.enable = false;
    };

    # theme.active = "alucard";
  };

  time.timeZone = "America/Chicago";

  boot.kernel.sysctl."net.ipv4.ip_forward" = 1;
  services.tailscale.extraSetFlags = [ "--advertise-routes=192.168.1.0/24" ];
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
      ProtectHome = "read-only";
      ReadWritePaths = [
        millDocsVaultPath
        "/home/emiller/.config/op"
        "/home/emiller/.config/obsidian-headless"
      ];
      NoNewPrivileges = true;
      PrivateTmp = true;
    };
  };

  systemd.services.mill-docs-git-pull = {
    description = "Auto-pull Git changes into mill-docs vault";
    after = [
      "network-online.target"
      "obsidian-sync-mill-docs.service"
    ];
    wants = [
      "network-online.target"
      "obsidian-sync-mill-docs.service"
    ];
    serviceConfig = {
      Type = "oneshot";
      User = "emiller";
      Group = "users";
      WorkingDirectory = millDocsVaultPath;
      ExecStart = "${millDocsGitPullScript}";
      TimeoutStartSec = "2min";
      ProtectHome = "read-only";
      ReadWritePaths = [ millDocsVaultPath ];
      NoNewPrivileges = true;
      PrivateTmp = true;
    };
  };

  systemd.timers.mill-docs-git-pull = {
    description = "Auto-pull Git changes into mill-docs vault on a short interval";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = "1min";
      OnUnitActiveSec = "5min";
      RandomizedDelaySec = "30s";
      Unit = "mill-docs-git-pull.service";
    };
  };

  # Replay Echo on iOS can fail SSH negotiation with newer OpenSSH defaults.
  # Keep modern algorithms while allowing conservative legacy fallbacks.
  services.openssh.settings =
    let
      host_key_algorithms = lib.concatStringsSep "," [
        "ssh-ed25519"
        "ecdsa-sha2-nistp256"
        "ecdsa-sha2-nistp384"
        "ecdsa-sha2-nistp521"
        "rsa-sha2-512"
        "rsa-sha2-256"
        "ssh-rsa"
      ];
      pubkey_accepted_algorithms = lib.concatStringsSep "," [
        "ssh-ed25519"
        "sk-ssh-ed25519@openssh.com"
        "ecdsa-sha2-nistp256"
        "ecdsa-sha2-nistp384"
        "ecdsa-sha2-nistp521"
        "sk-ecdsa-sha2-nistp256@openssh.com"
        "rsa-sha2-512"
        "rsa-sha2-256"
        "ssh-rsa"
      ];
    in
    {
      # Replay Echo / NIOSSH compatibility: avoid bleeding-edge-only defaults
      # that some mobile SSH stacks currently choke on.
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
      HostKeyAlgorithms = host_key_algorithms;
      PubkeyAcceptedAlgorithms = pubkey_accepted_algorithms;
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
      githubNixToken = {
        reference = "op://Agents/GH PA dotfiles flake/credential";
      };
      radarAgentmailCredential = {
        reference = "op://Agents/Radar Agentmail/credential";
      };
    };
  };

  systemd.services.nixos-upgrade = {
    after = [ "opnix-secrets.service" ];
    requires = [ "opnix-secrets.service" ];
    script = lib.mkForce ''
      exec ${nixPrivateGithub}/bin/nix-private-github \
        ${config.system.build.nixos-rebuild}/bin/nixos-rebuild \
        ${config.system.autoUpgrade.operation} ${toString config.system.autoUpgrade.flags}
    '';
  };

  age = {
    secrets = {
      lubelogger-env.owner = "lubelogger";
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
