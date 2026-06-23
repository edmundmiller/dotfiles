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
  launchPath = concatStringsSep ":" [
    "/etc/profiles/per-user/${config.user.name}/bin"
    "/run/current-system/sw/bin"
    "${config.user.home}/.nix-profile/bin"
    "${config.user.home}/.pi/agent/bin"
    "${config.user.home}/.bun/bin"
    "${config.user.home}/.local/bin"
    "${config.user.home}/.pixi/bin"
    "${config.user.home}/.cargo/bin"
    config.dotfiles.binDir
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
        [session]
        resume_agents_on_restore = true

        [experimental]
        pane_history = true

        [keys]
        prefix = "${cfg.prefix}"
        new_workspace = "prefix+w"
        new_worktree = "prefix+g"
        goto = "prefix+f"
        open_worktree = "prefix+G"
        workspace_picker = "prefix+O"
        split_horizontal = "prefix+-"
        toggle_sidebar = "prefix+b"
        previous_tab = "prefix+p"
        next_tab = "prefix+n"

        [[keys.command]]
        key = "prefix+u"
        type = "plugin_action"
        command = "dotfiles.dev-layout.hunk-split"
        description = "open hunk diff in a side pane"

        [[keys.command]]
        key = "prefix+U"
        type = "plugin_action"
        command = "dotfiles.dev-layout.hunk-tab"
        description = "open hunk diff in a tab"

        [[keys.command]]
        key = "prefix+a"
        type = "plugin_action"
        command = "nathanflurry.jj-workspace.new"
        description = "new jj workspace"

        [[keys.command]]
        key = "prefix+A"
        type = "plugin_action"
        command = "nathanflurry.jj-workspace.new-tab"
        description = "new jj workspace in a tab"

        [[keys.command]]
        key = "prefix+d"
        type = "plugin_action"
        command = "nathanflurry.jj-workspace.remove"
        description = "remove jj workspace"

        [[keys.command]]
        key = "prefix+V"
        type = "shell"
        command = "obsidian-neovide"
      '';

  # Pi's built-in theme can be too low-contrast in some Herdr/Ghostty stacks
  # (especially muted prompt text). Ship an optional high-contrast theme for
  # hosts that want Pi managed with Herdr.
  #
  # `piThemeVariant` swaps the underlying palette so hosts with a non-Catppuccin
  # terminal background (e.g. Seqera dark purple #201637) can use a palette
  # tuned for that background instead of letting the default dim/muted slots
  # collapse into the background.
  piThemePalettes = {
    default = {
      base = "#eff1f5";
      surface0 = "#ccd0da";
      surface1 = "#bcc0cc";
      surface2 = "#acb0be";
      text = "#4c4f69";
      subtext1 = "#5c5f77";
      subtext0 = "#6c6f85";
      overlay1 = "#7c7f93";
      mauve = "#8839ef";
      blue = "#1e66f5";
      sapphire = "#209fb5";
      teal = "#179299";
      green = "#40a02b";
      yellow = "#df8e1d";
      peach = "#fe640b";
      red = "#d20f39";
      toolPendingBg = "#e6e9ef";
      toolSuccessBg = "#dcead8";
      toolErrorBg = "#f2d5dc";
    };
    # Tuned for Seqera ghostty themes (background #201637 dark purple).
    # `subtext0`/`overlay1` are pushed brighter so the pi-sub-bar and other
    # `dim`/`muted` slots remain legible on the lower-contrast background.
    seqera = {
      base = "#201637";
      surface0 = "#2e2244";
      surface1 = "#3d2f5a";
      surface2 = "#4c3d70";
      text = "#e2f7f3";
      subtext1 = "#c8d9d6";
      subtext0 = "#b6c7c4";
      overlay1 = "#9aa9ad";
      mauve = "#cba6f7";
      blue = "#88baff";
      sapphire = "#5ea0ff";
      teal = "#31c9ac";
      green = "#95bf2f";
      yellow = "#f4e19a";
      peach = "#fab387";
      red = "#f38ba8";
      toolPendingBg = "#2a1f48";
      toolSuccessBg = "#1f3a30";
      toolErrorBg = "#3a1f30";
    };
  };

  piThemeBaseName = "dotfiles-herdr";
  piThemeName =
    if cfg.piThemeVariant == "default" then
      piThemeBaseName
    else
      "${piThemeBaseName}-${cfg.piThemeVariant}";
  piThemeVars = piThemePalettes.${cfg.piThemeVariant};

  # Herdr UI theme (separate from the Pi popup theme above). Each variant
  # is rendered into `[theme]` / `[theme.custom]` blocks by the bootstrap
  # activation.
  herdrThemePalettes = {
    default = {
      name = "terminal";
      custom = {
        panel_bg = "reset";
        surface0 = "#ccd0da";
        surface1 = "#bcc0cc";
        surface_dim = "#dce0e8";
        overlay0 = "#8c8fa1";
        overlay1 = "#7c7f93";
        text = "#4c4f69";
        subtext0 = "#6c6f85";
        accent = "#1e66f5";
        blue = "#1e66f5";
        green = "#40a02b";
        yellow = "#df8e1d";
        red = "#d20f39";
        teal = "#179299";
        peach = "#fe640b";
        mauve = "#8839ef";
      };
    };
    catppuccin-auto = {
      name = "terminal";
      custom = {
        panel_bg = "reset";
      };
    };
    seqera = {
      name = "terminal";
      custom = {
        panel_bg = "reset";
        accent = "#31c9ac";
        green = "#95bf2f";
        blue = "#5ea0ff";
        red = "#f38ba8";
        yellow = "#e6d06c";
      };
    };
  };
  herdrTheme = herdrThemePalettes.${cfg.themeVariant};
  piThemeFile = pkgs.writeText "${piThemeName}.json" ''
    {
      "$schema": "https://raw.githubusercontent.com/badlogic/pi-mono/main/packages/coding-agent/src/modes/interactive/theme/theme-schema.json",
      "name": "${piThemeName}",
      "vars": {
        "base": "${piThemeVars.base}",
        "surface0": "${piThemeVars.surface0}",
        "surface1": "${piThemeVars.surface1}",
        "surface2": "${piThemeVars.surface2}",
        "text": "${piThemeVars.text}",
        "subtext1": "${piThemeVars.subtext1}",
        "subtext0": "${piThemeVars.subtext0}",
        "overlay1": "${piThemeVars.overlay1}",
        "mauve": "${piThemeVars.mauve}",
        "blue": "${piThemeVars.blue}",
        "sapphire": "${piThemeVars.sapphire}",
        "teal": "${piThemeVars.teal}",
        "green": "${piThemeVars.green}",
        "yellow": "${piThemeVars.yellow}",
        "peach": "${piThemeVars.peach}",
        "red": "${piThemeVars.red}"
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
        "toolPendingBg": "${piThemeVars.toolPendingBg}",
        "toolSuccessBg": "${piThemeVars.toolSuccessBg}",
        "toolErrorBg": "${piThemeVars.toolErrorBg}",
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
    managePiTheme = mkBoolOpt true;
    piThemeVariant = mkOption {
      type = enum (attrNames piThemePalettes);
      default = "default";
      description = ''
        Which palette variant to ship as the Pi `dotfiles-herdr` theme.
        `default` is tuned for the Ghostty light theme; use `seqera` on hosts
        whose ghostty background is the Seqera dark purple (`#201637`).
      '';
    };
    themeVariant = mkOption {
      type = enum (attrNames herdrThemePalettes);
      default = "default";
      description = ''
        Which Herdr UI theme variant to apply via `[theme]` / `[theme.custom]`.
        `catppuccin-auto` leaves Catppuccin polarity to Ghostty and terminal
        defaults; `seqera` adds Seqera brand accents.
      '';
    };
    piThemeName = mkOption {
      type = str;
      readOnly = true;
      default = piThemeName;
      description = "Active Pi theme name shipped by the herdr module.";
    };
    integrations = {
      pi.enable = mkOption {
        type = bool;
        default = true;
        description = ''
          Automatically install Herdr's Pi integration when
          `modules.agents.pi.enable` is true.
        '';
      };

      claude.enable = mkOption {
        type = bool;
        default = true;
        description = ''
          Automatically install Herdr's Claude Code integration when
          `modules.agents.claude.enable` is true.
        '';
      };

      codex.enable = mkOption {
        type = bool;
        default = true;
        description = ''
          Automatically install Herdr's Codex integration when
          `modules.agents.codex.enable` is true.
        '';
      };

      opencode.enable = mkOption {
        type = bool;
        default = true;
        description = ''
          Automatically install Herdr's OpenCode integration when
          `modules.agents.opencode.enable` is true.
        '';
      };

      hermes.enable = mkOption {
        type = bool;
        default = true;
        description = ''
          Automatically install Herdr's Hermes integration for the managed
          `modules.agents.hermes` runtime and every declared
          `services.hermes-agent.profiles` NixOS profile.
        '';
      };
    };
  };

  config = mkIf cfg.enable {
    modules.shell.herdr.package = mkDefault pkgs.my.herdr;
    modules.shell.herdr.configFile = mkDefault "${config.dotfiles.configDir}/herdr/config.toml";

    user.packages = optional (cfg.package != null) cfg.package;
    environment.systemPackages = optional (cfg.package != null) cfg.package;

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

          # pi-computer-use's macOS TCC workaround is auto-enabled for SSH
          # sessions, but Herdr's persistent server can also be launched outside
          # the normal GUI-responsible process chain. Force the helper through
          # the user's GUI launchd domain so Accessibility/Screen Recording
          # grants are checked in the same context as a local GUI terminal.
          export PI_COMPUTER_USE_GUI_SESSION_LAUNCH="''${PI_COMPUTER_USE_GUI_SESSION_LAUNCH:-1}"

          # Resolve herdr from the managed profile first. User-level bins stay
          # on PATH for helper commands, but should not shadow the Nix-managed
          # Herdr package used to launch the server.
          herdr_cmd="''${HERDR_BIN_PATH:-${cfg.command}}"
          export HERDR_BIN_PATH="$herdr_cmd"

          if command -v "$herdr_cmd" >/dev/null 2>&1; then
            state_dir="''${XDG_STATE_HOME:-$HOME/.local/state}/herdr"
            version_stamp="$state_dir/launcher-version"
            current_version="$($herdr_cmd --version 2>/dev/null || true)"

            # Never stop Herdr from a Ghostty launch. If a protocol bump requires
            # a restart, surface it and let the user choose when to close panes.
            if [[ -n "$current_version" ]]; then
              mkdir -p "$state_dir"
              previous_version="$(cat "$version_stamp" 2>/dev/null || true)"
              if [[ -n "$previous_version" && "$previous_version" != "$current_version" ]]; then
                echo "open-herdr.sh: Herdr version changed; restart manually if attach fails." >&2
              fi
              printf '%s\n' "$current_version" > "$version_stamp"
            fi

            exec "$herdr_cmd"
          fi

          echo "open-herdr.sh: herdr command not found: $herdr_cmd" >&2
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
          ${pkgs.python3}/bin/python3 - "$target" ${escapeShellArg cfg.prefix} ${escapeShellArg herdrTheme.name} ${escapeShellArg (builtins.toJSON herdrTheme.custom)} <<'PY'
          import json
          import pathlib
          import sys

          path = pathlib.Path(sys.argv[1])
          prefix = sys.argv[2]
          theme_name = sys.argv[3]
          theme_custom = json.loads(sys.argv[4])
          lines = path.read_text().splitlines()
          managed_commands = {
              "herdr-tab previous",
              "herdr-tab next",
              "herdr-hunk",
              "herdr-hunk --tab",
              "herdr-worktree-layout",
              "herdr hunk",
              "herdr hunk --tab",
              "herdr worktree layout",
              "dotfiles.dev-layout.hunk-split",
              "dotfiles.dev-layout.hunk-tab",
              "nathanflurry.jj-workspace.new",
              "nathanflurry.jj-workspace.new-tab",
              "nathanflurry.jj-workspace.remove",
              "obsidian-neovide",
          }

          # Drop old/managed command blocks before appending the canonical ones.
          # This keeps activation idempotent and cleans up stale direct-key
          # bindings from older configs.
          filtered = []
          i = 0
          while i < len(lines):
              if lines[i].strip() == "[[keys.command]]":
                  block = [lines[i]]
                  i += 1
                  while i < len(lines) and not lines[i].strip().startswith("["):
                      block.append(lines[i])
                      i += 1

                  command = None
                  for block_line in block:
                      stripped = block_line.strip()
                      if stripped.startswith("command") and "=" in stripped:
                          command = stripped.split("=", 1)[1].strip().strip('"')
                          break

                  if command in managed_commands:
                      continue

                  filtered.extend(block)
                  continue

              filtered.append(lines[i])
              i += 1

          lines = filtered
          out = []
          in_keys = False
          saw_keys = False
          managed_keys = {
              "prefix": prefix,
              "new_workspace": "prefix+w",
              "new_worktree": "prefix+g",
              "goto": "prefix+f",
              "open_worktree": "prefix+G",
              "workspace_picker": "prefix+O",
              "split_horizontal": "prefix+-",
              "toggle_sidebar": "prefix+b",
              "previous_tab": "prefix+p",
              "next_tab": "prefix+n",
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
              'key = "prefix+u"',
              'type = "plugin_action"',
              'command = "dotfiles.dev-layout.hunk-split"',
              'description = "open hunk diff in a side pane"',
              "",
              "[[keys.command]]",
              'key = "prefix+U"',
              'type = "plugin_action"',
              'command = "dotfiles.dev-layout.hunk-tab"',
              'description = "open hunk diff in a tab"',
              "",
              "[[keys.command]]",
              'key = "prefix+a"',
              'type = "plugin_action"',
              'command = "nathanflurry.jj-workspace.new"',
              'description = "new jj workspace"',
              "",
              "[[keys.command]]",
              'key = "prefix+A"',
              'type = "plugin_action"',
              'command = "nathanflurry.jj-workspace.new-tab"',
              'description = "new jj workspace in a tab"',
              "",
              "[[keys.command]]",
              'key = "prefix+d"',
              'type = "plugin_action"',
              'command = "nathanflurry.jj-workspace.remove"',
              'description = "remove jj workspace"',
              "",
              "[[keys.command]]",
              'key = "prefix+V"',
              'type = "shell"',
              'command = "obsidian-neovide"',
          ]

          if out and out[-1].strip():
              out.append("")
          out.extend(command_block[1:])

          def upsert_worktree_directory(lines):
              out = []
              in_worktrees = False
              saw_worktrees = False
              wrote_directory = False

              for line in lines:
                  stripped = line.strip()
                  if stripped.startswith("[") and stripped.endswith("]"):
                      if in_worktrees and not wrote_directory:
                          out.append('directory = "~/.local/share/herdr/worktrees"')
                      in_worktrees = stripped == "[worktrees]"
                      saw_worktrees = saw_worktrees or in_worktrees
                      out.append(line)
                      continue

                  if in_worktrees and "=" in stripped:
                      key = stripped.split("=", 1)[0].strip()
                      if key == "directory":
                          if not wrote_directory:
                              out.append('directory = "~/.local/share/herdr/worktrees"')
                              wrote_directory = True
                          continue
                      if key == "post_create_command":
                          # Herdr 0.7 plugin events replace the old dotfiles-only
                          # post-create shell hook.
                          continue

                  out.append(line)

              if saw_worktrees and in_worktrees and not wrote_directory:
                  out.append('directory = "~/.local/share/herdr/worktrees"')
              elif not saw_worktrees:
                  if out and out[-1].strip():
                      out.append("")
                  out.extend([
                      "[worktrees]",
                      'directory = "~/.local/share/herdr/worktrees"',
                  ])

              return out

          def upsert_simple_section(lines, section, managed_values):
              out = []
              in_section = False
              saw_section = False
              wrote = set()

              header = f"[{section}]"
              for line in lines:
                  stripped = line.strip()
                  if stripped.startswith("[") and stripped.endswith("]"):
                      if in_section:
                          for key, value in managed_values.items():
                              if key not in wrote:
                                  out.append(f"{key} = {value}")
                                  wrote.add(key)
                      in_section = stripped == header
                      saw_section = saw_section or in_section
                      out.append(line)
                      continue

                  if in_section and "=" in stripped:
                      key = stripped.split("=", 1)[0].strip()
                      if key in managed_values:
                          if key not in wrote:
                              out.append(f"{key} = {managed_values[key]}")
                              wrote.add(key)
                          continue

                  out.append(line)

              if saw_section and in_section:
                  for key, value in managed_values.items():
                      if key not in wrote:
                          out.append(f"{key} = {value}")
                          wrote.add(key)
              elif not saw_section:
                  if out and out[-1].strip():
                      out.append("")
                  out.append(header)
                  for key, value in managed_values.items():
                      out.append(f"{key} = {value}")

              return out

          def replace_section(lines, header, body_lines):
              # Remove any existing block whose header matches exactly, then
              # append the new block at the end. Exact-match keeps sub-tables
              # such as `[theme.custom]` independent of `[theme]`.
              out = []
              in_target = False
              for line in lines:
                  stripped = line.strip()
                  if stripped.startswith("[") and stripped.endswith("]"):
                      in_target = stripped == header
                      if in_target:
                          continue
                      out.append(line)
                      continue
                  if in_target:
                      continue
                  out.append(line)

              if body_lines:
                  if out and out[-1].strip():
                      out.append("")
                  out.append(header)
                  out.extend(body_lines)
              return out

          out = upsert_worktree_directory(out)
          out = upsert_simple_section(out, "session", {"resume_agents_on_restore": "true"})
          out = upsert_simple_section(out, "experimental", {"pane_history": "true"})
          out = replace_section(out, "[theme]", [f'name = "{theme_name}"'])
          out = replace_section(
              out,
              "[theme.custom]",
              [f'{k} = "{v}"' for k, v in theme_custom.items()],
          )

          path.write_text("\n".join(out) + "\n")
          PY
        '';

        home.activation.herdr-plugin-registry = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
          plugins_root=${escapeShellArg "${config.dotfiles.configDir}/herdr/plugins"}
          registry="$HOME/.config/herdr/plugins.json"
          ${pkgs.coreutils}/bin/mkdir -p "$(${pkgs.coreutils}/bin/dirname "$registry")"

          ${pkgs.python3}/bin/python3 - "$registry" "$plugins_root" <<'PY'
          import json
          import pathlib
          import sys
          import tomllib

          registry = pathlib.Path(sys.argv[1])
          plugins_root = pathlib.Path(sys.argv[2])
          managed_roots = [
              plugins_root / "dotfiles-dev-layout",
              plugins_root / "dotfiles-github-link-preview",
          ]

          def load_existing():
              if not registry.exists():
                  return []
              try:
                  data = json.loads(registry.read_text())
                  return data if isinstance(data, list) else []
              except Exception:
                  return []

          def manifest_entry(root):
              manifest_path = root / "herdr-plugin.toml"
              manifest = tomllib.loads(manifest_path.read_text())
              plugin_id = manifest["id"]
              source = {
                  "kind": "local",
                  "owner": None,
                  "repo": None,
                  "subdir": None,
                  "requested_ref": None,
                  "resolved_commit": None,
                  "managed_path": None,
                  "installed_unix_ms": None,
              }
              return {
                  "plugin_id": plugin_id,
                  "name": manifest["name"],
                  "version": manifest["version"],
                  "min_herdr_version": manifest["min_herdr_version"],
                  "description": manifest.get("description"),
                  "manifest_path": str(manifest_path),
                  "plugin_root": str(root),
                  "enabled": True,
                  "platforms": manifest.get("platforms"),
                  "build": manifest.get("build", []),
                  "actions": manifest.get("actions", []),
                  "events": manifest.get("events", []),
                  "panes": manifest.get("panes", []),
                  "link_handlers": manifest.get("link_handlers", []),
                  "source": source,
                  "warnings": [],
              }

          existing = load_existing()
          managed = {entry["plugin_id"]: entry for entry in map(manifest_entry, managed_roots)}
          merged = [entry for entry in existing if entry.get("plugin_id") not in managed]
          merged.extend(managed[plugin_id] for plugin_id in sorted(managed))
          registry.write_text(json.dumps(merged, indent=2) + "\n")
          PY
        '';

        home.activation.herdr-marketplace-plugins =
          lib.hm.dag.entryAfter
            [
              "writeBoundary"
              "herdr-plugin-registry"
            ]
            ''
              export PATH=$PATH:${escapeShellArg launchPath}
              herdr_cmd=${escapeShellArg cfg.command}

              if "$herdr_cmd" plugin list --json --plugin nathanflurry.jj-workspace | ${pkgs.gnugrep}/bin/grep -q '"plugin_id"[[:space:]]*:[[:space:]]*"nathanflurry.jj-workspace"'; then
                echo "herdr: nathanflurry.jj-workspace plugin already installed"
              else
                echo "herdr: installing nathanflurry.jj-workspace plugin"
                "$herdr_cmd" plugin install NathanFlurry/herdr-plugin-jj-workspace --yes
              fi
            '';

        home.activation.herdr-agent-integrations =
          lib.hm.dag.entryAfter
            [
              "writeBoundary"
              "pi-extension-conflict-cleanup"
              "claude-settings-bootstrap"
              "codex-config-bootstrap"
              "opencode-setup"
              "hermes-bootstrap"
            ]
            ''
              # Preserve Home Manager's activation PATH first: it contains GNU
              # find. Putting /usr/bin before it makes HM's own cleanup step
              # call BSD find, which lacks -printf.
              export PATH=$PATH:${escapeShellArg launchPath}
              herdr_cmd=${escapeShellArg cfg.command}

              install_integration() {
                target="$1"
                echo "herdr: installing $target integration"
                "$herdr_cmd" integration install "$target" >/dev/null
              }

              ${optionalString (cfg.integrations.pi.enable && config.modules.agents.pi.enable) ''
                ${pkgs.coreutils}/bin/mkdir -p "$HOME/.pi/agent/extensions"
                PI_CODING_AGENT_DIR="$HOME/.pi/agent" install_integration pi
              ''}

              ${optionalString (cfg.integrations.claude.enable && config.modules.agents.claude.enable) ''
                ${pkgs.coreutils}/bin/mkdir -p "$HOME/.claude"
                install_integration claude
              ''}

              ${optionalString (cfg.integrations.codex.enable && config.modules.agents.codex.enable) ''
                ${pkgs.coreutils}/bin/mkdir -p "$HOME/.codex"
                install_integration codex
              ''}

              ${optionalString (cfg.integrations.opencode.enable && config.modules.agents.opencode.enable) ''
                ${pkgs.coreutils}/bin/mkdir -p "$HOME/.config/opencode"
                XDG_CONFIG_HOME="$HOME/.config" install_integration opencode
              ''}

              ${optionalString (cfg.integrations.hermes.enable && config.modules.agents.hermes.enable) ''
                ${pkgs.coreutils}/bin/mkdir -p ${escapeShellArg config.modules.agents.hermes.homeDir}
                HOME=${escapeShellArg config.user.home} \
                  HERMES_HOME=${escapeShellArg config.modules.agents.hermes.homeDir} \
                  install_integration hermes
              ''}
            '';
      };

    modules.shell.tmux.rcFiles = mkIf tmuxEnabled (mkAfter [
      "${config.user.home}/.config/tmux/herdr.conf"
    ]);
  };
}
