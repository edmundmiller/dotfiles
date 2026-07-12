{
  config,
  lib,
  pkgs,
  inputs,
  isDarwin,
  ...
}:
with lib;
with lib.my;
let
  cfg = config.modules.shell.git;
  inherit (config.dotfiles) configDir;
  hunkPackageBase = inputs.hunk.packages.${pkgs.stdenv.hostPlatform.system}.default;
  hunkPackagePatched = hunkPackageBase.overrideAttrs (old: {
    patches = (old.patches or [ ]) ++ [
      ../../../overlays/hunk/patches/0001-add-source-switch-menu.patch
      ../../../overlays/hunk/patches/0002-add-which-key.patch
    ];
  });
  hunkPackage =
    if pkgs.stdenv.hostPlatform.isDarwin then
      hunkPackagePatched.overrideAttrs (old: {
        postInstall = (old.postInstall or "") + ''
          chmod u+w $out/bin/hunk
          /usr/bin/codesign -f -s - $out/bin/hunk
        '';
      })
    else
      hunkPackagePatched;
  hunkThemeDark = if cfg.hunk.theme.dark == null then "" else cfg.hunk.theme.dark;
  hunkThemeLight = if cfg.hunk.theme.light == null then "" else cfg.hunk.theme.light;
  hunkThemeConfig = if cfg.hunk.theme.config == null then hunkThemeDark else cfg.hunk.theme.config;
  hunkConfigText =
    if hunkThemeConfig == "" then
      builtins.readFile "${configDir}/hunk/config.toml"
    else
      replaceStrings [ ''theme = "auto"'' ] [ ''theme = "${hunkThemeConfig}"'' ] (
        builtins.readFile "${configDir}/hunk/config.toml"
      );
  hunkPackageWrapped = pkgs.writeShellApplication {
    name = "hunk";
    text = ''
      real_hunk=${hunkPackage}/bin/hunk

      if [[ "''${1:-}" == "diff" ]]; then
        has_theme=false
        has_background=false
        for arg in "$@"; do
          case "$arg" in
            --theme|--theme=*) has_theme=true ;;
            --transparent-bg|--no-transparent-bg) has_background=true ;;
          esac
        done

        extra=()
        if [[ "$has_theme" == false ]]; then
          dark_theme=${escapeShellArg hunkThemeDark}
          light_theme=${escapeShellArg hunkThemeLight}
          if [[ "$(${pkgs.coreutils}/bin/uname -s)" == "Darwin" ]]; then
            dark_mode=$(/usr/bin/osascript -e 'tell application "System Events" to tell appearance preferences to get dark mode' 2>/dev/null || true)
            if [[ "$dark_mode" == "true" && -n "$dark_theme" ]]; then
              extra+=(--theme "$dark_theme")
            elif [[ "$dark_mode" == "false" && -n "$light_theme" ]]; then
              extra+=(--theme "$light_theme")
            fi
          elif [[ -n "$dark_theme" ]]; then
            extra+=(--theme "$dark_theme")
          fi
        fi
        if [[ "$has_background" == false ]]; then
          extra+=(${
            if cfg.hunk.theme.transparentBackground then "--transparent-bg" else "--no-transparent-bg"
          })
        fi

        shift
        exec "$real_hunk" diff "''${extra[@]}" "$@"
      fi

      exec "$real_hunk" "$@"
    '';
  };
in
{
  options.modules.shell.git = {
    enable = mkBoolOpt false;
    ai.enable = mkBoolOpt false;
    hunk.enable = mkBoolOpt false;
    hunk.theme = {
      dark = mkOpt (types.nullOr types.str) null;
      light = mkOpt (types.nullOr types.str) null;
      config = mkOpt (types.nullOr types.str) null;
      transparentBackground = mkBoolOpt false;
    };
    gitbutler.enable = mkBoolOpt false;
    gitnexus.enable = mkBoolOpt false;
    lazydiff.enable = mkBoolOpt false;
    diffity.enable = mkBoolOpt false;
    stack.enable = mkBoolOpt false;
  };

  config = mkIf cfg.enable (mkMerge [
    (mkIf cfg.ai.enable {
      modules.agents.pi.extraPackages = mkIf config.modules.agents.pi.enable [
        "~/.config/dotfiles/packages/pi-packages/pi-git-ai"
      ];
    })

    {
      user.packages =
        with pkgs;
        [
          git-open
          difftastic
          delta # for lazygit paging
          (mkIf config.modules.shell.gnupg.enable git-crypt)
          git-lfs
          pre-commit
          my.git-hunks
          (mkIf cfg.ai.enable my.git-ai)
          (mkIf cfg.gitbutler.enable llm-agents.but)
          (mkIf cfg.gitbutler.enable llm-agents.gitbutler)
          (mkIf cfg.gitnexus.enable llm-agents.gitnexus)
          (mkIf cfg.hunk.enable hunkPackageWrapped)
          (mkIf cfg.lazydiff.enable my.lazydiff)
          (mkIf cfg.stack.enable my.stack)
        ]
        ++ lib.optionals stdenv.hostPlatform.isDarwin (
          [
            my.sem # semantic git diff/impact/blame
            my.inspect # entity-level code review triage
            my.weave # entity-level semantic merge driver
          ]
          ++ lib.optional cfg.diffity.enable my.diffity # GitHub-style diff viewer/code review
        );

      environment.systemPackages = lib.optional isDarwin pkgs.my.lgtm;

      # Use home-manager's xdg.configFile directly for proper activation
      home-manager.users.${config.user.name} =
        { lib, ... }:
        {
          home.activation.git-ai-trace-cleanup = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
            if ${pkgs.git}/bin/git config --global --get trace2.eventTarget 2>/dev/null | ${pkgs.gnugrep}/bin/grep -q '\.git-ai'; then
              ${pkgs.git}/bin/git config --global --unset-all trace2.eventTarget || true
              ${pkgs.git}/bin/git config --global --unset-all trace2.eventNesting || true
            fi
          '';

          home.activation.git-ai-agent-hook-cleanup = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
            ${pkgs.python3}/bin/python3 - "$HOME/.factory/settings.json" <<'PY'
            import json
            import pathlib
            import sys

            path = pathlib.Path(sys.argv[1])
            if not path.exists():
                raise SystemExit(0)

            try:
                data = json.loads(path.read_text(encoding="utf-8"))
            except Exception:
                raise SystemExit(0)

            stale_git_ai = "/Users/emiller/.git-ai/bin/git-ai checkpoint droid --hook-input stdin"
            hooks = data.get("hooks")
            changed = False
            if isinstance(hooks, dict):
                for event, entries in list(hooks.items()):
                    if not isinstance(entries, list):
                        continue

                    next_entries = []
                    for entry in entries:
                        if not isinstance(entry, dict):
                            next_entries.append(entry)
                            continue

                        hook_list = entry.get("hooks")
                        if not isinstance(hook_list, list):
                            next_entries.append(entry)
                            continue

                        filtered_hooks = [
                            hook
                            for hook in hook_list
                            if not (
                                isinstance(hook, dict)
                                and hook.get("command") == stale_git_ai
                            )
                        ]
                        if filtered_hooks != hook_list:
                            changed = True
                        if filtered_hooks:
                            next_entry = dict(entry)
                            next_entry["hooks"] = filtered_hooks
                            next_entries.append(next_entry)

                    if next_entries != entries:
                        changed = True
                    hooks[event] = next_entries

            if changed:
                path.write_text(json.dumps(data, indent=2) + "\n", encoding="utf-8")
            PY
          '';

          xdg.configFile = {
            "git/config".source = "${configDir}/git/config";
            "git/config-signing" =
              if isDarwin then
                {
                  source = "${configDir}/git/config-signing";
                }
              else
                {
                  text = ''
                    [commit]
                        gpgsign = false
                    [tag]
                        gpgSign = false
                  '';
                };
            "git/config-seqera".source = "${configDir}/git/config-seqera";
            "git/config-nfcore".source = "${configDir}/git/config-nfcore";
            "git/ignore".source = "${configDir}/git/ignore";
            "git/allowed_signers".source = "${configDir}/git/allowed_signers";
            # GitHub CLI config (hosts.yml intentionally NOT managed — gh writes
            # token/scope metadata to it after auth; Nix store symlink would block that)
            "gh/config.yml".source = "${configDir}/gh/config.yml";
            # GitHub Dashboard config
            "gh-dash/config.yml".source = "${configDir}/gh-dash/config.yml";
            # Lazygit config
            "lazygit/config.yml" = {
              text = builtins.readFile "${configDir}/lazygit/config.yml";
              force = true;
            };
          }
          // optionalAttrs cfg.hunk.enable {
            "hunk/config.toml".text = hunkConfigText;
          };
        };

      modules.shell.zsh.rcFiles = [ "${configDir}/git/aliases.zsh" ];

      environment.variables.GHUI_PR_FETCH_LIMIT = "100";
    }

    (optionalAttrs isDarwin {
      homebrew.brews = [ "kitlangton/tap/ghui" ];
    })
  ]);
}
