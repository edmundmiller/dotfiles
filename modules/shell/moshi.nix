{
  config,
  lib,
  isDarwin,
  ...
}:
with lib;
with lib.my;
let
  cfg = config.modules.shell.moshi;
  inherit (config.dotfiles) configDir;

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
  options.modules.shell.moshi = {
    enable = mkBoolOpt false;
    tmuxHelper.enable = mkBoolOpt config.modules.shell.tmux.enable;

    hooks = {
      enable = mkBoolOpt true;
      autoTargets.enable = mkBoolOpt true;
      extraTargets = mkOpt' (types.listOf (types.enum supportedHookTargets)) [ ] ''
        Additional moshi-hook targets to install on this host. Enabled agent
        modules are discovered automatically when autoTargets is enabled.
      '';
    };
  };

  config = mkIf cfg.enable {
    modules.shell.zsh.rcFiles = mkIf cfg.tmuxHelper.enable [ "${configDir}/moshi/aliases.zsh" ];

    home-manager.users.${config.user.name} = mkIf (isDarwin && cfg.hooks.enable && hookTargets != [ ]) (
      { lib, ... }:
      {
        home.activation.moshi-agent-hook-install = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
          moshi_hook=""
          for candidate in \
            "$HOME/.nix-profile/bin/moshi-hook" \
            "/etc/profiles/per-user/$USER/bin/moshi-hook" \
            "/run/current-system/sw/bin/moshi-hook" \
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
          elif ! "$moshi_hook" install ${hookTargetsArgs}; then
            echo "warning: moshi-hook install failed for targets: ${concatStringsSep ", " hookTargets}" >&2
          fi
        '';
      }
    );
  };
}
