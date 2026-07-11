# Moshi — mobile app integration for agent events and host helpers
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
  cfg = config.modules.services.moshi;
  inherit (config.dotfiles) configDir;

  moshiHookVersion = "0.2.39";
  moshiHookAssets = {
    aarch64-darwin = {
      asset = "moshi-hook_Darwin_arm64.tar.gz";
      hash = "sha256-ChQ34uBF5yquZemsvpZMxz4ZXYsl89VvA37RXAvnmeg=";
    };
    aarch64-linux = {
      asset = "moshi-hook_Linux_arm64.tar.gz";
      hash = "sha256-jE4559ZM6QJw209GAZYg+Th1JKM+mNvEPlTPJ6Kmi7c=";
    };
    x86_64-darwin = {
      asset = "moshi-hook_Darwin_x86_64.tar.gz";
      hash = "sha256-JXO1pPKlBfiYhCGrvVPT33sDEOOn/i1SemoYdPrMiPs=";
    };
    x86_64-linux = {
      asset = "moshi-hook_Linux_x86_64.tar.gz";
      hash = "sha256-CAd+x0Bb4+b9z832Sv2UGMtWDs43xXaD4DUjuVMotKQ=";
    };
  };
  moshiHookAsset = moshiHookAssets.${pkgs.stdenv.hostPlatform.system};
  moshiHook = pkgs.stdenvNoCC.mkDerivation {
    pname = "moshi-hook";
    version = moshiHookVersion;

    src = pkgs.fetchurl {
      url = "https://cdn.getmoshi.app/hook/v${moshiHookVersion}/${moshiHookAsset.asset}";
      inherit (moshiHookAsset) hash;
    };

    sourceRoot = ".";
    installPhase = ''
      runHook preInstall
      install -Dm755 moshi-hook "$out/bin/moshi-hook"
      ln -s moshi-hook "$out/bin/moshi"
      runHook postInstall
    '';
  };

  # Moshi hooks have two paths:
  #
  # - Upstream targets below are installed by `moshi-hook install --target ...`.
  #   autoTargets keeps enabled local agent modules wired without repeating
  #   host-specific target lists.
  # - Custom targets live here when the upstream installer has no target for
  #   that agent yet. Keep those idempotent and merge into mutable user config
  #   instead of overwriting agent-owned settings.
  #
  # All platforms use the pinned Nix moshiHook package. Darwin runs it via
  # launchd; Linux runs it from the user systemd daemon.
  supportedHookTargets = [
    "claude"
    "codex"
    "omp"
    "opencode"
    "pi"
  ];

  autoHookTargets = unique (
    optionals config.modules.agents.claude.enable [ "claude" ]
    ++ optionals config.modules.agents.codex.enable [ "codex" ]
    ++ optionals config.modules.agents.omp.enable [ "omp" ]
    ++ optionals config.modules.agents.opencode.enable [ "opencode" ]
    ++ optionals config.modules.agents.pi.enable [ "pi" ]
  );

  # Droid is custom because `moshi-hook install --target` does not expose a
  # Droid target. Droid accepts Claude-style hooks, so merge Moshi commands into
  # Factory's hook config when the Kittylitter Droid bridge is enabled.
  droidHookEnabled =
    config.modules.services.kittylitter.enable
    && elem "droid" config.modules.services.kittylitter.enabledAgents;
  droidHookCommand =
    if isDarwin then
      "'/run/current-system/sw/bin/moshi-hook' claude-hook"
    else
      "'/run/current-system/sw/bin/moshi-hook' claude-hook";

  hookTargets = unique (
    (optionals cfg.hooks.autoTargets.enable autoHookTargets) ++ cfg.hooks.extraTargets
  );

  hookTargetsArgs = concatMapStringsSep " " (target: "--target ${escapeShellArg target}") hookTargets;
  upstreamHookTargets = filter (target: target != "omp" && target != "opencode") hookTargets;
  upstreamHookTargetsArgs = concatMapStringsSep " " (
    target: "--target ${escapeShellArg target}"
  ) upstreamHookTargets;
  ompHookEnabled = elem "omp" hookTargets;
  opencodeHookEnabled = elem "opencode" hookTargets;
in
{
  options.modules.services.moshi = {
    enable = mkBoolOpt false;
    hookSecretsFile = mkOpt' (types.nullOr types.path) null ''
      Optional secrets.json file for the moshi-hook daemon. When null, the
      moshi-hook package and configured agent hooks are installed, but no
      NixOS user daemon is enabled.
    '';

    hooks = {
      enable = mkBoolOpt true;
      autoTargets.enable = mkBoolOpt true;
      extraTargets = mkOpt' (types.listOf (types.enum supportedHookTargets)) [ ] ''
        Additional upstream moshi-hook install targets to install on this host.
        Enabled agent modules are discovered automatically when autoTargets is
        enabled. Droid is handled separately because moshi-hook does not expose
        it as an install target.
      '';
    };

    shell = {
      enable = mkBoolOpt true;
      tmuxHelper.enable = mkBoolOpt config.modules.shell.tmux.enable;
    };
  };

  config = mkIf cfg.enable (mkMerge [
    {
      # Keep moshi-hook on the system profile so agent hooks and non-login
      # shells resolve the pinned Nix-managed helper.
      environment.systemPackages = [ moshiHook ];
      user.packages = [ moshiHook ];

      modules.shell.zsh.rcFiles = mkIf cfg.shell.enable (
        mkIf cfg.shell.tmuxHelper.enable [ "${configDir}/moshi/aliases.zsh" ]
      );

      home-manager.users.${config.user.name} =
        { lib, ... }:
        {
          home.activation = mkMerge [
            (optionalAttrs isDarwin {
              moshi-homebrew-cleanup = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
                launchctl bootout "gui/$(${pkgs.coreutils}/bin/id -u)/homebrew.mxcl.moshi-hook" 2>/dev/null || true
                rm -f "$HOME/Library/LaunchAgents/homebrew.mxcl.moshi-hook.plist"
                /usr/bin/pkill -u "$USER" -f '/opt/homebrew/.*/moshi-hook serve|/opt/homebrew/bin/moshi-hook serve' 2>/dev/null || true
              '';
            })

            (optionalAttrs isDarwin (
              mkIf (cfg.hooks.enable && (upstreamHookTargets != [ ] || ompHookEnabled || opencodeHookEnabled)) {
                moshi-agent-hook-install =
                  lib.hm.dag.entryAfter
                    [
                      "writeBoundary"
                      "claude-settings-bootstrap"
                      "codex-config-bootstrap"
                      "herdr-agent-integrations"
                    ]
                    ''
                      moshi_hook=""
                      for candidate in \
                        "/run/current-system/sw/bin/moshi-hook" \
                        "/etc/profiles/per-user/$USER/bin/moshi-hook" \
                        "$HOME/.nix-profile/bin/moshi-hook" \
                        "/opt/homebrew/bin/moshi-hook"
                      do
                        if [ -x "$candidate" ]; then
                          moshi_hook="$candidate"
                          break
                        fi
                      done

                      if [ -z "$moshi_hook" ] && command -v moshi-hook >/dev/null 2>&1; then
                        moshi_hook="$(command -v moshi-hook)"
                      fi

                      if [ -z "$moshi_hook" ]; then
                        echo "warning: moshi-hook not found; skipping Moshi agent hook install" >&2
                      else
                        ${optionalString (upstreamHookTargets != [ ]) ''
                          if ! "$moshi_hook" install ${upstreamHookTargetsArgs}; then
                            echo "warning: moshi-hook install failed for targets: ${concatStringsSep ", " upstreamHookTargets}" >&2
                          fi
                        ''}

                        ${optionalString ompHookEnabled ''
                          if ! PI_CONFIG_DIR="$HOME/.omp" PI_CODING_AGENT_DIR="$HOME/.omp/agent" "$moshi_hook" install --target omp; then
                            echo "warning: moshi-hook install failed for target: omp" >&2
                          fi

                          rm -f "$HOME/.pi/agent/hooks/post/moshi-hooks.ts"
                        ''}

                        ${optionalString opencodeHookEnabled ''
                          if ! XDG_CONFIG_HOME="$HOME/.config/opencode2" "$moshi_hook" install --target opencode; then
                            echo "warning: moshi-hook install failed for target: opencode" >&2
                          fi
                        ''}
                      fi
                    '';
              }
            ))

            (mkIf (cfg.hooks.enable && droidHookEnabled) {
              moshi-droid-hook-install = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
                ${pkgs.python3}/bin/python3 <<'PY'
                import json
                import os
                import pathlib
                import tempfile

                factory_dir = pathlib.Path.home() / ".factory"
                hooks_path = factory_dir / "hooks.json"
                settings_path = factory_dir / "settings.json"
                path = hooks_path if hooks_path.exists() or not settings_path.exists() else settings_path
                command = ${builtins.toJSON droidHookCommand}
                events = [
                    "Notification",
                    "SessionEnd",
                    "SessionStart",
                    "Stop",
                    "UserPromptSubmit",
                ]

                factory_dir.mkdir(parents=True, exist_ok=True)
                if path.exists():
                    try:
                        data = json.loads(path.read_text())
                    except Exception as exc:
                        print(f"warning: invalid Droid hook JSON in {path}; skipping Moshi hook install: {exc}", file=os.sys.stderr)
                        raise SystemExit(0)
                else:
                    data = {}

                if not isinstance(data, dict):
                    print(f"warning: Droid hook JSON root in {path} is not an object; skipping Moshi hook install", file=os.sys.stderr)
                    raise SystemExit(0)

                if path == hooks_path:
                    hooks = data
                else:
                    hooks = data.setdefault("hooks", {})
                    if not isinstance(hooks, dict):
                        print(f"warning: Droid hooks in {path} is not an object; skipping Moshi hook install", file=os.sys.stderr)
                        raise SystemExit(0)

                hook = {
                    "type": "command",
                    "command": command,
                    "timeout": 10,
                }
                changed = False

                for event in events:
                    groups = hooks.setdefault(event, [])
                    if not isinstance(groups, list):
                        print(f"warning: Droid hook event {event} is not a list; skipping it", file=os.sys.stderr)
                        continue
                    if any(
                        isinstance(group, dict)
                        and any(
                            isinstance(item, dict)
                            and item.get("type") == "command"
                            and item.get("command") == command
                            for item in group.get("hooks", [])
                        )
                        for group in groups
                    ):
                        continue
                    groups.append({"hooks": [hook]})
                    changed = True

                if not changed:
                    raise SystemExit(0)

                fd, tmp_name = tempfile.mkstemp(prefix=path.name + ".", suffix=".tmp", dir=path.parent)
                with os.fdopen(fd, "w") as tmp:
                    json.dump(data, tmp, indent=2)
                    tmp.write("\n")
                os.chmod(tmp_name, 0o600)
                os.replace(tmp_name, path)
                PY
              '';
            })
          ];
        };
    }

    (optionalAttrs isDarwin {
      launchd.user.agents.moshi-hook = {
        command = "${moshiHook}/bin/moshi-hook serve";
        serviceConfig = {
          RunAtLoad = true;
          KeepAlive = true;
          StandardOutPath = "${config.user.home}/Library/Logs/moshi-hook.log";
          StandardErrorPath = "${config.user.home}/Library/Logs/moshi-hook.err.log";
          EnvironmentVariables = {
            HOME = config.user.home;
            PATH = "/run/current-system/sw/bin:/etc/profiles/per-user/${config.user.name}/bin:/usr/bin:/bin:/usr/sbin:/sbin";
          };
        };
      };
    })

    (optionalAttrs (!isDarwin) (
      mkIf (cfg.hookSecretsFile != null) {
        home-manager.users.${config.user.name}.systemd.user.services.moshi-hook = {
          Unit = {
            Description = "Moshi hook daemon";
            Documentation = [ "https://getmoshi.app" ];
            ConditionFileNotEmpty = cfg.hookSecretsFile;
          };

          Service = {
            ExecStartPre = [
              "${pkgs.coreutils}/bin/mkdir -p %h/.local/state/moshi"
              "${pkgs.coreutils}/bin/install -m 600 ${cfg.hookSecretsFile} %h/.local/state/moshi/secrets.json"
            ]
            ++ optionals (cfg.hooks.enable && hookTargets != [ ]) [
              "-${moshiHook}/bin/moshi-hook install ${hookTargetsArgs}"
            ];
            ExecStart = "${moshiHook}/bin/moshi-hook serve";
            Restart = "always";
            RestartSec = 10;
          };

          Install.WantedBy = [ "default.target" ];
        };
      }
    ))
  ]);
}
