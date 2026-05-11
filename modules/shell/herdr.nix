{
  config,
  lib,
  pkgs,
  ...
}:
with lib;
with lib.my;
let
  cfg = config.modules.shell.herdr;
  tmuxEnabled = config.modules.shell.tmux.enable;

  herdrBin = if cfg.package != null then "${cfg.package}/bin/${cfg.command}" else cfg.command;

  launchPath = concatStringsSep ":" [
    "${config.user.home}/.pi/agent/bin"
    "${config.user.home}/.bun/bin"
    "${config.user.home}/.local/bin"
    "${config.user.home}/.pixi/bin"
    "${config.user.home}/.cargo/bin"
    config.dotfiles.binDir
    "${config.user.home}/.nix-profile/bin"
    "/etc/profiles/per-user/${config.user.name}/bin"
    "/run/current-system/sw/bin"
    "/nix/var/nix/profiles/default/bin"
    "/usr/local/bin"
    "/usr/bin"
    "/bin"
    "/usr/sbin"
    "/sbin"
  ];

  herdrConfigTemplate =
    if cfg.configFile != null then
      cfg.configFile
    else
      pkgs.writeText "herdr-config.toml" ''
        # Seeded by nix. Herdr keeps this file writable after bootstrap.
        [keys]
        prefix = "${cfg.prefix}"
        new_workspace = "w"
        split_horizontal = "s"

        [[keys.command]]
        key = "p"
        type = "shell"
        command = "herdr-tab previous"

        [[keys.command]]
        key = "n"
        type = "shell"
        command = "herdr-tab next"

        [[keys.command]]
        key = "["
        type = "shell"
        command = "herdr-hunk"

        [[keys.command]]
        key = "]"
        type = "shell"
        command = "herdr-hunk --tab"
      '';

  # Pi's auto-selected dark theme can be too low-contrast in the Herdr/Ghostty
  # popup (especially muted prompt text). Ship and select a small Catppuccin-ish
  # theme with brighter foregrounds so the input box remains readable.
  piThemeName = "dotfiles-herdr";
  piThemeFile = pkgs.writeText "${piThemeName}.json" ''
    {
      "$schema": "https://raw.githubusercontent.com/badlogic/pi-mono/main/packages/coding-agent/src/modes/interactive/theme/theme-schema.json",
      "name": "${piThemeName}",
      "vars": {
        "base": "#1e1e2e",
        "surface0": "#313244",
        "surface1": "#45475a",
        "surface2": "#585b70",
        "text": "#cdd6f4",
        "subtext1": "#bac2de",
        "subtext0": "#a6adc8",
        "overlay1": "#7f849c",
        "mauve": "#cba6f7",
        "blue": "#89b4fa",
        "sapphire": "#74c7ec",
        "teal": "#94e2d5",
        "green": "#a6e3a1",
        "yellow": "#f9e2af",
        "peach": "#fab387",
        "red": "#f38ba8"
      },
      "colors": {
        "accent": "teal",
        "border": "blue",
        "borderAccent": "teal",
        "borderMuted": "surface2",
        "success": "green",
        "error": "red",
        "warning": "yellow",
        "muted": "subtext0",
        "dim": "overlay1",
        "text": "text",
        "thinkingText": "subtext1",
        "selectedBg": "surface0",
        "userMessageBg": "surface0",
        "userMessageText": "text",
        "customMessageBg": "surface0",
        "customMessageText": "text",
        "customMessageLabel": "mauve",
        "toolPendingBg": "#242438",
        "toolSuccessBg": "#243826",
        "toolErrorBg": "#3a2430",
        "toolTitle": "sapphire",
        "toolOutput": "text",
        "mdHeading": "mauve",
        "mdLink": "blue",
        "mdLinkUrl": "sapphire",
        "mdCode": "teal",
        "mdCodeBlock": "text",
        "mdCodeBlockBorder": "surface2",
        "mdQuote": "subtext0",
        "mdQuoteBorder": "surface2",
        "mdHr": "surface2",
        "mdListBullet": "teal",
        "toolDiffAdded": "green",
        "toolDiffRemoved": "red",
        "toolDiffContext": "subtext0",
        "syntaxComment": "overlay1",
        "syntaxKeyword": "mauve",
        "syntaxFunction": "blue",
        "syntaxVariable": "peach",
        "syntaxString": "green",
        "syntaxNumber": "peach",
        "syntaxType": "yellow",
        "syntaxOperator": "mauve",
        "syntaxPunctuation": "subtext0",
        "thinkingOff": "surface2",
        "thinkingMinimal": "teal",
        "thinkingLow": "sapphire",
        "thinkingMedium": "blue",
        "thinkingHigh": "mauve",
        "thinkingXhigh": "red",
        "bashMode": "yellow"
      }
    }
  '';
in
{
  options.modules.shell.herdr = with types; {
    enable = mkBoolOpt false;
    package = mkOpt (nullOr package) null;
    command = mkOpt str "herdr";
    configFile = mkOpt (nullOr (either str path)) null;
    prefix = mkOpt str "ctrl+c";
    key = mkOpt str "H";
    popupWidth = mkOpt int 90;
    popupHeight = mkOpt int 90;
  };

  config = mkIf cfg.enable {
    modules.shell.herdr.package = mkDefault (pkgs.my.herdr or pkgs.herdr or null);
    modules.shell.herdr.configFile = mkDefault "${config.dotfiles.configDir}/herdr/config.toml";

    user.packages = optional (cfg.package != null) cfg.package;

    home.file.".pi/agent/themes/${piThemeName}.json".source = piThemeFile;

    home.configFile = {
      "tmux/open-herdr.sh" = {
        executable = true;
        text = ''
          #!${pkgs.bash}/bin/bash
          set -euo pipefail

          if [[ -n "''${PATH:-}" ]]; then
            export PATH='${launchPath}':"$PATH"
          else
            export PATH='${launchPath}'
          fi

          # Start from home so herdr doesn't land in '/' when Ghostty launches from Finder.
          cd "$HOME"

          herdr_cmd='${herdrBin}'
          export HERDR_BIN_PATH="$herdr_cmd"

          if command -v "$herdr_cmd" >/dev/null 2>&1; then
            if "$herdr_cmd"; then
              exit 0
            fi
          fi

          # Safety fallback: if herdr is unavailable or fails, prefer tmux when present,
          # otherwise drop into the user's login shell.
          if command -v tmux >/dev/null 2>&1; then
            exec tmux new-session -A -s home
          fi

          exec "''${SHELL:-${pkgs.bashInteractive}/bin/bash}" -l
        '';
      };
    }
    // optionalAttrs tmuxEnabled {
      "tmux/herdr.conf".text = ''
        # Optional herdr integration (generated by nix)
        bind-key ${cfg.key} display-popup -E -w ${toString cfg.popupWidth}% -h ${toString cfg.popupHeight}% "$TMUX_HOME/open-herdr.sh"
      '';
    };

    home-manager.users.${config.user.name} =
      { lib, ... }:
      {
        home.activation.herdr-config-bootstrap = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
          herdr_dir="$HOME/.config/herdr"
          target="$herdr_dir/config.toml"
          template="${herdrConfigTemplate}"

          ${pkgs.coreutils}/bin/mkdir -p "$herdr_dir"

          # Herdr updates onboarding/settings in config.toml, so keep a writable local
          # copy and only bootstrap from the nix-managed template when needed.
          # TODO: if herdr grows a way to disable onboarding/settings writes, switch
          # this back to a declarative read-only config file.
          if [ -L "$target" ]; then
            tmp="$(${pkgs.coreutils}/bin/mktemp)"
            ${pkgs.coreutils}/bin/cp -L "$target" "$tmp" 2>/dev/null || ${pkgs.coreutils}/bin/cp "$template" "$tmp"
            ${pkgs.coreutils}/bin/rm -f "$target"
            ${pkgs.coreutils}/bin/mv "$tmp" "$target"
          elif [ ! -e "$target" ]; then
            ${pkgs.coreutils}/bin/cp "$template" "$target"
          fi

          ${pkgs.coreutils}/bin/chmod u+w "$target" 2>/dev/null || true

          # Keep the managed prefix in sync even after the initial bootstrap.
          # Herdr's config stays writable for onboarding/settings, so existing
          # files need an explicit upsert rather than only copying the template.
          ${pkgs.python3}/bin/python3 - "$target" ${escapeShellArg cfg.prefix} <<'PY'
          import pathlib
          import sys

          path = pathlib.Path(sys.argv[1])
          prefix = sys.argv[2]
          lines = path.read_text().splitlines()
          out = []
          in_keys = False
          saw_keys = False
          managed_keys = {
              "prefix": prefix,
              "new_workspace": "w",
              "split_horizontal": "s",
          }
          wrote_keys = set()

          for line in lines:
              stripped = line.strip()
              if stripped.startswith("[") and stripped.endswith("]"):
                  if in_keys:
                      for key, value in managed_keys.items():
                          if key not in wrote_keys:
                              out.append(f'{key} = "{value}"')
                              wrote_keys.add(key)
                  in_keys = stripped == "[keys]"
                  saw_keys = saw_keys or in_keys
                  out.append(line)
                  continue

              if in_keys and "=" in stripped:
                  key = stripped.split("=", 1)[0].strip()
                  if key in managed_keys:
                      if key not in wrote_keys:
                          out.append(f'{key} = "{managed_keys[key]}"')
                          wrote_keys.add(key)
                      continue

              out.append(line)

          if saw_keys and in_keys:
              for key, value in managed_keys.items():
                  if key not in wrote_keys:
                      out.append(f'{key} = "{value}"')
                      wrote_keys.add(key)

          if not saw_keys:
              if out and out[-1].strip():
                  out.append("")
              out.append("[keys]")
              for key, value in managed_keys.items():
                  out.append(f'{key} = "{value}"')

          command_block = [
              "",
              "[[keys.command]]",
              'key = "p"',
              'type = "shell"',
              'command = "herdr-tab previous"',
              "",
              "[[keys.command]]",
              'key = "n"',
              'type = "shell"',
              'command = "herdr-tab next"',
              "",
              "[[keys.command]]",
              'key = "["',
              'type = "shell"',
              'command = "herdr-hunk"',
              "",
              "[[keys.command]]",
              'key = "]"',
              'type = "shell"',
              'command = "herdr-hunk --tab"',
          ]

          content = "\n".join(out)
          if "herdr-tab previous" not in content or "herdr-tab next" not in content or "herdr-hunk" not in content:
              if out and out[-1].strip():
                  out.append("")
              out.extend(command_block[1:])

          path.write_text("\n".join(out) + "\n")
          PY
        '';
      };

    modules.shell.tmux.rcFiles = mkIf tmuxEnabled (mkAfter [
      "${config.user.home}/.config/tmux/herdr.conf"
    ]);
  };
}
