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

  moshiHookVersion = "0.2.34";
  moshiHookAssets = {
    aarch64-darwin = {
      asset = "moshi-hook_Darwin_arm64.tar.gz";
      hash = "sha256-7fwmj1z0q81O5U0VNu0+T8Ju1tw+0s2GFUxo7gZJwos=";
    };
    aarch64-linux = {
      asset = "moshi-hook_Linux_arm64.tar.gz";
      hash = "sha256-KWxgX7p3Xn39ZwllYyEnnOxDIWdWjmDGjoW1TXu15HI=";
    };
    x86_64-darwin = {
      asset = "moshi-hook_Darwin_x86_64.tar.gz";
      hash = "sha256-fxvXPcnDSyIR5plq0a1lYATEW+usGE/tpte2KMGnk9U=";
    };
    x86_64-linux = {
      asset = "moshi-hook_Linux_x86_64.tar.gz";
      hash = "sha256-5w6qXzNYzMNAgPfvNWbqG5Fnn9HSdJGHKyGysPQ8rD8=";
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

  supportedHookTargets = [
    "claude"
    "codex"
    "opencode"
    "pi"
  ];

  autoHookTargets = unique (
    optionals config.modules.agents.claude.enable [ "claude" ]
    ++ optionals config.modules.agents.codex.enable [ "codex" ]
    ++ optionals config.modules.agents.opencode.enable [ "opencode" ]
    ++ optionals config.modules.agents.pi.enable [ "pi" ]
  );

  hookTargets = unique (
    (optionals cfg.hooks.autoTargets.enable autoHookTargets) ++ cfg.hooks.extraTargets
  );

  hookTargetsArgs = concatMapStringsSep " " (target: "--target ${escapeShellArg target}") hookTargets;
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
        Additional moshi-hook targets to install on this host. Enabled agent
        modules are discovered automatically when autoTargets is enabled.
      '';
    };

    shell = {
      enable = mkBoolOpt true;
      tmuxHelper.enable = mkBoolOpt config.modules.shell.tmux.enable;
    };
  };

  config = mkIf cfg.enable (mkMerge [
    {
      # On Darwin the daemon is Homebrew-managed so launchd, upgrades, and the
      # helper path stay consistent. Linux still uses the Nix-built hook.
      environment.systemPackages = optionals (!isDarwin) [ moshiHook ];
      user.packages = optionals (!isDarwin) [ moshiHook ];

      modules.shell.zsh.rcFiles = mkIf cfg.shell.enable (
        mkIf cfg.shell.tmuxHelper.enable [ "${configDir}/moshi/aliases.zsh" ]
      );

      home-manager.users.${config.user.name} = mkIf (isDarwin && cfg.hooks.enable && hookTargets != [ ]) (
        { lib, ... }:
        {
          home.activation.moshi-agent-hook-install =
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
                  "/opt/homebrew/bin/moshi-hook" \
                  "$HOME/.nix-profile/bin/moshi-hook" \
                  "/etc/profiles/per-user/$USER/bin/moshi-hook" \
                  "/run/current-system/sw/bin/moshi-hook"
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
                elif ! "$moshi_hook" install ${hookTargetsArgs}; then
                  echo "warning: moshi-hook install failed for targets: ${concatStringsSep ", " hookTargets}" >&2
                fi
              '';
        }
      );
    }

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
