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

  moshiHookVersion = "0.2.70";
  moshiHookAssets = {
    aarch64-darwin = {
      asset = "moshi-hook_Darwin_arm64.tar.gz";
      hash = "sha256-98awucTGha++yIqoRW7aiX3I1YgKNRKUKn0JFgR2WGE=";
    };
    aarch64-linux = {
      asset = "moshi-hook_Linux_arm64.tar.gz";
      hash = "sha256-31mO6KHW+Sn0S5oavYExNg7mdRI3jqsv3HCyaVWKXHg=";
    };
    x86_64-darwin = {
      asset = "moshi-hook_Darwin_x86_64.tar.gz";
      hash = "sha256-refs+zUHOxNeGpRuVCBPGVn/mXD4MREf5LkTEZ2bS8Q=";
    };
    x86_64-linux = {
      asset = "moshi-hook_Linux_x86_64.tar.gz";
      hash = "sha256-2jGe40N3f+Hp3aWc3TwfAUpYCh2Ba4wbEzLWQSIkNU8=";
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
        enabled.
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

          ];
        };
    }

    (optionalAttrs isDarwin {
      # nix-darwin only reloads unchanged launch agents when their plist changes.
      # Reconcile Moshi on every activation so a registered dormant job heals.
      system.activationScripts.postActivation.text = mkAfter ''
        moshi_uid=$(/usr/bin/id -u ${escapeShellArg config.user.name})
        if /bin/launchctl print "gui/$moshi_uid/org.nixos.moshi-hook" >/dev/null 2>&1; then
          /bin/launchctl asuser "$moshi_uid" /usr/bin/sudo --user=${escapeShellArg config.user.name} -- \
            /bin/launchctl kickstart -k "gui/$moshi_uid/org.nixos.moshi-hook"
        fi
      '';

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
