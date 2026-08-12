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
  managedLocalPlugins = pkgs.symlinkJoin {
    name = "dotfiles-managed-herdr-plugins";
    paths = [
      pkgs.my.herdr-plugins
      pkgs.my.herdr-plugin-jj-workspace
      pkgs.my.herdr-tab-smart-rename
    ]
    ++ optional cfg.vercelSandbox.enable pkgs.my.herdr-vercel-sandbox-plugin;
  };
  launchPath = concatStringsSep ":" [
    "${pkgs.my.rift}/bin"
    "/etc/profiles/per-user/${config.user.name}/bin"
    "/run/current-system/sw/bin"
    "${config.user.home}/.nix-profile/bin"
    "${config.user.home}/.pi/agent/bin"
    "${config.user.home}/.bun/bin"
    "${config.user.home}/.local/bin"
    "${config.user.home}/.pixi/bin"
    "${config.user.home}/.cargo/bin"
    "${pkgs.cargo}/bin"
    "${pkgs.rustc}/bin"
    config.dotfiles.binDir
    "/nix/var/nix/profiles/default/bin"
    "/usr/local/bin"
    "/usr/bin"
    "/bin"
    "/usr/sbin"
    "/sbin"
  ];

  herdrConfigTemplate = cfg.configFile;
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
    localPluginsPackage = mkOpt package managedLocalPlugins;
    command = mkOpt str "herdr";
    configFile = mkOpt (nullOr (either str path)) null;
    key = mkOpt str "H";
    mainCodingAgent = mkOpt (enum [
      "pi"
      "omp"
      "claude"
      "codex"
      "opencode"
    ]) "pi";
    vercelSandbox.enable = mkBoolOpt false;
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

      omp.enable = mkOption {
        type = bool;
        default = true;
        description = ''
          Automatically install Herdr's OMP integration when
          `modules.agents.omp.enable` is true.
        '';
      };

      droid.enable = mkOption {
        type = bool;
        default = true;
        description = ''
          Automatically install Herdr's Droid integration when the
          `modules.services.kittylitter` Droid bridge is enabled.
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
    env.HERDR_MAIN_CODING_AGENT = cfg.mainCodingAgent;

    home.file.".local/bin/rift".source = lib.getExe pkgs.my.rift;
    home.file.".pi/agent/themes/${piThemeName}.json".source = piThemeFile;

    home.configFile = {
      "ghzinga/config.toml".source = "${config.dotfiles.configDir}/ghzinga/config.toml";

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
          export HERDR_MAIN_CODING_AGENT=${escapeShellArg cfg.mainCodingAgent}
          ${optionalString (config.modules.shell.git.hunk.theme.dark != null) ''
            export HUNK_THEME_DARK=${escapeShellArg config.modules.shell.git.hunk.theme.dark}
          ''}
          ${optionalString (config.modules.shell.git.hunk.theme.light != null) ''
            export HUNK_THEME_LIGHT=${escapeShellArg config.modules.shell.git.hunk.theme.light}
          ''}

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
    // optionalAttrs cfg.vercelSandbox.enable {
      "herdr/plugins/config/vercel.sandbox/config.json".text = ''
        {
          "agentKind": "omp",
          "allowCandidateAgents": true,
          "agentArgs": {
            "codex": [],
            "omp": [],
            "opencode-v2": []
          },
          "customAgents": {
            "omp": {
              "title": "OMP",
              "installationCommand": "npm install --prefix /vercel/sandbox/.herdr-tools bun@1.3.14 @oh-my-pi/pi-coding-agent@17.2.12",
              "launchCommand": "env PATH=/vercel/sandbox/.herdr-tools/node_modules/.bin:$PATH PI_CONFIG_DIR=.omp PI_CODING_AGENT_DIR=/vercel/sandbox/.omp/agent /vercel/sandbox/.herdr-tools/node_modules/.bin/omp",
              "versionCommand": "PATH=/vercel/sandbox/.herdr-tools/node_modules/.bin:$PATH /vercel/sandbox/.herdr-tools/node_modules/.bin/omp --version",
              "expectedVersion": "17.2.12",
              "authenticationMode": "device-code",
              "herdrDetectionIdentifier": "omp",
              "interactiveTTY": true,
              "resumeSupported": true
            },
            "opencode-v2": {
              "title": "OpenCode V2 beta",
              "installationCommand": "npm install --prefix /vercel/sandbox/.herdr-tools opencode-ai@0.0.0-beta-202608091410",
              "launchCommand": "/vercel/sandbox/.herdr-tools/node_modules/.bin/opencode",
              "versionCommand": "/vercel/sandbox/.herdr-tools/node_modules/.bin/opencode --version",
              "expectedVersion": "0.0.0-beta-202608091410",
              "authenticationMode": "provider-dependent",
              "herdrDetectionIdentifier": "opencode",
              "interactiveTTY": true,
              "resumeSupported": true
            }
          },
          "image": "vercel/sandbox/universal:latest",
          "timeout": "1h",
          "uploadExcludes": [],
          "sensitiveFileOverrides": []
        }
      '';
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

          # Herdr's config stays writable for onboarding/settings, so reapply
          # values from the selected template rather than only copying it once.
          ${pkgs.python3}/bin/python3 - "$target" "$template" ${escapeShellArg herdrTheme.name} ${escapeShellArg (builtins.toJSON herdrTheme.custom)} <<'PY'
          import json
          import pathlib
          import sys
          import tomllib

          path = pathlib.Path(sys.argv[1])
          template_path = pathlib.Path(sys.argv[2])
          canonical_config = tomllib.loads(template_path.read_text())
          canonical_keys = canonical_config.get("keys", {})
          canonical_commands = canonical_keys.get("command", [])
          theme_name = sys.argv[3]
          theme_custom = json.loads(sys.argv[4])
          lines = path.read_text().splitlines()

          def toml_value(value):
              if isinstance(value, bool):
                  return "true" if value else "false"
              if isinstance(value, str):
                  return json.dumps(value, ensure_ascii=False)
              if isinstance(value, (int, float)):
                  return str(value)
              if isinstance(value, list):
                  return "[" + ", ".join(toml_value(item) for item in value) + "]"
              if isinstance(value, dict):
                  entries = ", ".join(
                      f"{key} = {toml_value(item)}" for key, item in value.items()
                  )
                  return "{ " + entries + " }"
              raise TypeError(f"unsupported TOML value: {value!r}")

          canonical_command_names = {
              command["command"]
              for command in canonical_commands
              if isinstance(command.get("command"), str)
          }
          managed_commands = set(canonical_command_names)
          managed_commands.update({
              "herdr-tab previous",
              "herdr-tab next",
              "herdr-hunk",
              "herdr-hunk --tab",
              "herdr-worktree-layout",
              "herdr hunk",
              "herdr hunk --tab",
              "herdr worktree layout",
              "nathanflurry.jj-workspace.new-tab",
              "vercel.sandbox.start-agent",
              "vercel.sandbox.start-codex",
              "vercel.sandbox.start-omp",
              "vercel.sandbox.start-opencode-v2",
              "vercel.sandbox.apply-changes",
              "vercel.sandbox.reconnect",
              "vercel.sandbox.stop",
              "vercel.sandbox.info",
              "obsidian-neovide",
          })

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
              key: value for key, value in canonical_keys.items() if key != "command"
          }
          wrote_keys = set()

          for line in lines:
              stripped = line.strip()
              if stripped.startswith("[") and stripped.endswith("]"):
                  if in_keys:
                      for key, value in managed_keys.items():
                          if key not in wrote_keys:
                              out.append(f"{key} = {toml_value(value)}")
                              wrote_keys.add(key)
                  in_keys = stripped == "[keys]"
                  saw_keys = saw_keys or in_keys
                  out.append(line)
                  continue

              if in_keys and "=" in stripped:
                  key = stripped.split("=", 1)[0].strip()
                  if key in managed_keys:
                      if key not in wrote_keys:
                          out.append(f"{key} = {toml_value(managed_keys[key])}")
                          wrote_keys.add(key)
                      continue

              out.append(line)

          if saw_keys and in_keys:
              for key, value in managed_keys.items():
                  if key not in wrote_keys:
                      out.append(f"{key} = {toml_value(value)}")
                      wrote_keys.add(key)

          if not saw_keys:
              if out and out[-1].strip():
                  out.append("")
              out.append("[keys]")
              for key, value in managed_keys.items():
                  out.append(f"{key} = {toml_value(value)}")

          command_block = []
          for command in canonical_commands:
              command_block.extend(["", "[[keys.command]]"])
              command_block.extend(
                  f"{key} = {toml_value(value)}" for key, value in command.items()
              )

          if "obsidian-neovide" not in canonical_command_names:
              command_block.extend([
                  "",
                  "[[keys.command]]",
                  'key = "prefix+V"',
                  'type = "shell"',
                  'command = "obsidian-neovide"',
              ])

          ${optionalString cfg.vercelSandbox.enable ''
            command_block.extend([
                "",
                "[[keys.command]]",
                'key = "prefix+S"',
                'type = "plugin_action"',
                'command = "vercel.sandbox.start-omp"',
                'description = "start OMP in a Vercel Sandbox"',
                "",
                "[[keys.command]]",
                'key = "prefix+alt+c"',
                'type = "plugin_action"',
                'command = "vercel.sandbox.start-codex"',
                'description = "start Codex in a Vercel Sandbox"',
                "",
                "[[keys.command]]",
                'key = "prefix+alt+o"',
                'type = "plugin_action"',
                'command = "vercel.sandbox.start-opencode-v2"',
                'description = "start OpenCode V2 beta in a Vercel Sandbox"',
                "",
                "[[keys.command]]",
                'key = "prefix+A"',
                'type = "plugin_action"',
                'command = "vercel.sandbox.apply-changes"',
                'description = "apply Vercel Sandbox changes locally"',
                "",
                "[[keys.command]]",
                'key = "prefix+C"',
                'type = "plugin_action"',
                'command = "vercel.sandbox.reconnect"',
                'description = "reconnect to the Vercel Sandbox"',
                "",
                "[[keys.command]]",
                'key = "prefix+Q"',
                'type = "plugin_action"',
                'command = "vercel.sandbox.stop"',
                'description = "stop Vercel Sandbox compute"',
                "",
                "[[keys.command]]",
                'key = "prefix+E"',
                'type = "plugin_action"',
                'command = "vercel.sandbox.info"',
                'description = "show Vercel Sandbox mapping"',
            ])
          ''}

          if out and out[-1].strip():
              out.append("")
          out.extend(command_block[1:])

          def remove_deprecated_worktree_keys(lines):
              out = []
              in_worktrees = False

              for line in lines:
                  stripped = line.strip()
                  if stripped.startswith("[") and stripped.endswith("]"):
                      in_worktrees = stripped == "[worktrees]"
                      out.append(line)
                      continue

                  if in_worktrees and "=" in stripped:
                      key = stripped.split("=", 1)[0].strip()
                      if key == "post_create_command":
                          # Herdr 0.7 plugin events replace the old dotfiles-only
                          # post-create shell hook.
                          continue

                  out.append(line)

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

          def managed_section(section):
              return {
                  key: toml_value(value)
                  for key, value in canonical_config.get(section, {}).items()
                  if not isinstance(value, dict)
              }

          out = remove_deprecated_worktree_keys(out)
          out = upsert_simple_section(out, "worktrees", managed_section("worktrees"))
          out = upsert_simple_section(out, "session", managed_section("session"))
          out = upsert_simple_section(out, "experimental", managed_section("experimental"))
          out = upsert_simple_section(out, "ui", managed_section("ui"))
          out = replace_section(out, "[theme]", [f'name = "{theme_name}"'])
          out = replace_section(
              out,
              "[theme.custom]",
              [f'{k} = "{v}"' for k, v in theme_custom.items()],
          )

          path.write_text("\n".join(out) + "\n")
          PY
        '';

        home.activation.herdr-plugin-registry = lib.hm.dag.entryAfter [ "herdr-marketplace-plugins" ] ''
          plugins_root=${escapeShellArg "${cfg.localPluginsPackage}/share/herdr/plugins"}
          registry="$HOME/.config/herdr/plugins.json"
          ${pkgs.coreutils}/bin/mkdir -p "$(${pkgs.coreutils}/bin/dirname "$registry")"

          ${pkgs.python3}/bin/python3 - "$registry" "$plugins_root" <<'PY'
          import json
          import pathlib
          import sys
          import tomllib

          registry = pathlib.Path(sys.argv[1])
          plugins_root = pathlib.Path(sys.argv[2])
          managed_roots = sorted(
              root for root in plugins_root.iterdir()
              if root.is_dir() and (root / "herdr-plugin.toml").exists()
          )

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
          export PATH=$PATH:${escapeShellArg launchPath}
          herdr_cmd=${escapeShellArg cfg.command}
          for plugin_root in "$plugins_root"/*; do
            if [ -f "$plugin_root/herdr-plugin.toml" ]; then
              if ! link_output=$("$herdr_cmd" plugin link "$plugin_root" 2>&1); then
                if printf '%s\n' "$link_output" | ${pkgs.gnugrep}/bin/grep -Eqi "Connection refused|protocol_mismatch"; then
                  echo "herdr: warning: runtime unavailable; deferring local plugin link for $plugin_root" >&2
                else
                  printf '%s\n' "$link_output" >&2
                  exit 1
                fi
              fi
            fi
          done
        '';

        home.activation.herdr-smart-rename = lib.hm.dag.entryAfter [ "herdr-plugin-registry" ] ''
          export PATH=$PATH:${escapeShellArg launchPath}
          herdr_cmd=${escapeShellArg cfg.command}
          if ! start_output=$("$herdr_cmd" plugin action invoke start --plugin tab-smart-rename 2>&1); then
            if printf '%s\n' "$start_output" | ${pkgs.gnugrep}/bin/grep -Eqi "Connection refused|protocol_mismatch"; then
              echo "herdr: warning: runtime unavailable; deferring smart rename worker start" >&2
            else
              printf '%s\n' "$start_output" >&2
              exit 1
            fi
          fi
        '';

        home.activation.herdr-marketplace-plugins = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
          export PATH=$PATH:${escapeShellArg launchPath}
          herdr_cmd=${escapeShellArg cfg.command}
          runtime_deferred=0

          install_plugin() {
            owner="$1"
            repo="$2"
            subdir="''${3:-}"
            mode="''${4:-required}"
            spec="$owner/$repo"
            if [ -n "$subdir" ]; then
              spec="$spec/$subdir"
            fi

            if [ "$runtime_deferred" -eq 1 ]; then
              return 0
            fi

            if ! installed_json=$("$herdr_cmd" plugin list --json 2>&1); then
              if printf '%s\n' "$installed_json" | ${pkgs.gnugrep}/bin/grep -Eqi "Connection refused|protocol_mismatch"; then
                echo "herdr: warning: runtime unavailable or outdated; deferring marketplace plugin installation" >&2
                runtime_deferred=1
                return 0
              fi
              printf '%s\n' "$installed_json" >&2
              echo "herdr: error: failed to list plugins before installing $spec" >&2
              return 1
            fi

            if printf '%s\n' "$installed_json" | ${pkgs.gnugrep}/bin/grep -q "\"owner\":\"$owner\",\"repo\":\"$repo\""; then
              echo "herdr: $spec plugin already installed"
            else
              echo "herdr: installing $spec plugin"
              if ! install_output=$("$herdr_cmd" plugin install "$spec" --yes 2>&1); then
                printf '%s\n' "$install_output" >&2
                if [ "$mode" = optional ] && printf '%s\n' "$install_output" | ${pkgs.gnugrep}/bin/grep -Eqi "not found|404|private|permission|could not read Username|authentication"; then
                  echo "herdr: warning: optional $spec plugin unavailable; continuing" >&2
                else
                  return 1
                fi
              fi
            fi
          }

          uninstall_plugin() {
            plugin_id="$1"

            if [ "$runtime_deferred" -eq 1 ]; then
              return 0
            fi

            if ! installed_json=$("$herdr_cmd" plugin list --json 2>&1); then
              if printf '%s\n' "$installed_json" | ${pkgs.gnugrep}/bin/grep -Eqi "Connection refused|protocol_mismatch"; then
                echo "herdr: warning: runtime unavailable or outdated; deferring marketplace plugin removal" >&2
                runtime_deferred=1
                return 0
              fi
              printf '%s\n' "$installed_json" >&2
              echo "herdr: error: failed to list plugins before removing $plugin_id" >&2
              return 1
            fi

            if printf '%s\n' "$installed_json" | ${pkgs.gnugrep}/bin/grep -q "\"plugin_id\":\"$plugin_id\""; then
              echo "herdr: removing $plugin_id plugin"
              if ! uninstall_output=$("$herdr_cmd" plugin uninstall "$plugin_id" 2>&1); then
                if printf '%s\n' "$uninstall_output" | ${pkgs.gnugrep}/bin/grep -Eqi "Connection refused|protocol_mismatch"; then
                  echo "herdr: warning: runtime unavailable or outdated; deferring $plugin_id removal" >&2
                  runtime_deferred=1
                  return 0
                fi
                printf '%s\n' "$uninstall_output" >&2
                return 1
              fi
            fi
          }

          jj_plugin_config=$("$herdr_cmd" plugin config-dir nathanflurry.jj-workspace)
          ${pkgs.coreutils}/bin/mkdir -p "$jj_plugin_config"
          ${pkgs.coreutils}/bin/cat > "$jj_plugin_config/.env" <<'EOF'
          JJ_BASE_REV=trunk()
          JJ_WORKSPACE_NAME_PREFIXES=issue-,pr-,task-
          EOF

          # Patched plugins are registered from Nix-managed local packages.
          uninstall_plugin rjyo.window-title-sync
          install_plugin smarzban herdr-file-viewer
          install_plugin dutifuldev ghzinga plugins/herdr
          install_plugin dcolinmorgan herdr-remote relay
          install_plugin razajamil herdr-plugin-workspace-manager
          install_plugin paulbkim-dev vim-herdr-navigation
          install_plugin ogulcancelik herdr-plugin-github-start
          install_plugin ogulcancelik herdr-browser
          install_plugin wyattjoh herdr-plugin-gh-pr
          install_plugin kkckkc herdr-plugin-gh-workflow
          install_plugin alon-z herdr-command-palette
          install_plugin 0x5c0f herdr-insight
          install_plugin persiyanov herdr-reviewr
          install_plugin edmundmiller herdr-which-key "" optional
        '';

        home.activation.herdr-agent-integrations =
          lib.hm.dag.entryAfter
            [
              "writeBoundary"
              "pi-extension-conflict-cleanup"
              "claude-settings-bootstrap"
              "codex-config-bootstrap"
              "opencode-v1-cleanup"
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
                ${pkgs.coreutils}/bin/mkdir -p "$HOME/.config/opencode2/opencode"
                ${pkgs.coreutils}/bin/ln -sfn "$HOME/.config/opencode2/opencode" "$HOME/.config/opencode"
                install_integration opencode
              ''}

              ${optionalString (cfg.integrations.omp.enable && config.modules.agents.omp.enable) ''
                ${pkgs.coreutils}/bin/mkdir -p "$HOME/.omp/agent/extensions"
                # Herdr 0.8 refuses to install OMP when Pi and OMP resolve to the
                # same extension directory. Activation may inherit
                # PI_CODING_AGENT_DIR=~/.omp/agent from the wrapped OMP that
                # launched the rebuild, which makes both sides resolve there.
                # Clear it so Pi falls back to ~/.pi/agent while PI_CONFIG_DIR
                # keeps OMP on ~/.omp/agent.
                PI_CODING_AGENT_DIR= PI_CONFIG_DIR=.omp install_integration omp
              ''}

              ${optionalString
                (
                  cfg.integrations.droid.enable
                  && config.modules.services.kittylitter.enable
                  && elem "droid" config.modules.services.kittylitter.enabledAgents
                )
                ''
                  ${pkgs.coreutils}/bin/mkdir -p "$HOME/.factory"
                  install_integration droid
                ''
              }

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
