{
  config,
  pkgs,
  lib,
  ...
}:
with lib;
with lib.my;
let
  cfg = config.modules.shell.tmux;
  inherit (config.dotfiles) configDir;

  # OpenCode / Claude status for tmux `status-right`.
  #
  # NOTE: Window naming is handled by tmux-opencode-integrated.
  # Avoid other renamers to keep names stable.
  #
  # States:
  # - ○ idle
  # - ● busy
  # - ◉ waiting (prompt/approval)
  # - ✗ error
  opencodeStatus = pkgs.writeShellScript "tmux-opencode-status" ''
    #!/usr/bin/env bash
    set -euo pipefail

    ICON_IDLE="○"
    ICON_BUSY="●"
    ICON_WAITING="◉"
    ICON_ERROR="✗"

    # Check if a pane is running a given tool.
    # - `pane_current_command` is fast but can be `node`, so we also inspect args.
    is_tool() {
      local tool="$1" cmd="$2" pid="$3"

      if [[ "$cmd" == "$tool" ]]; then
        return 0
      fi

      if [[ "$cmd" == "node" ]]; then
        ps -p "$pid" -o command= 2>/dev/null | grep -qiE "([[:space:]/]|^)($tool)([[:space:]]|$)" && return 0
      fi

      return 1
    }

    detect_state() {
      local pane_id="$1"

      # Grab a small tail of recent output for heuristics.
      local lines
      lines="$(tmux capture-pane -p -t "$pane_id" -S -12 2>/dev/null || true)"
      [[ -z "$lines" ]] && echo "idle" && return 0

      # Error: strong signals.
      if echo "$lines" | grep -qiE "(^|[[:space:]])(error:|failed|exception|fatal|panic:|traceback)([[:space:]]|$)"; then
        echo "error"
        return 0
      fi

      # Waiting: prompts / approvals.
      if echo "$lines" | tail -n 3 | grep -qiE "(\\[[Yy]/[Nn]\\]|\\[[yY]/[nN]\\]|\\[[Yy]/[Nn]/[Aa]\\]|Allow\\?|Deny\\?|Approve\\?|permission.*\\?)"; then
        echo "waiting"
        return 0
      fi

      # Busy: spinners / "thinking" / tool execution markers.
      if echo "$lines" | tail -n 2 | grep -qE "(⠋|⠙|⠹|⠸|⠼|⠴|⠦|⠧|⠇|⠏|◐|◓|◑|◒|\\.\\.\\.$)"; then
        echo "busy"
        return 0
      fi
      if echo "$lines" | tail -n 4 | grep -qiE "(^|[[:space:]])(thinking|tool:)([[:space:]]|$)"; then
        echo "busy"
        return 0
      fi

      echo "idle"
    }

    icon_for() {
      case "$1" in
        idle) echo "$ICON_IDLE" ;;
        busy) echo "$ICON_BUSY" ;;
        waiting) echo "$ICON_WAITING" ;;
        error) echo "$ICON_ERROR" ;;
        *) echo "$ICON_IDLE" ;;
      esac
    }

    main() {
      local oc_icons="" cc_icons=""

      # Current window only (keeps status-right cheap and stable).
      local win_id
      win_id="$(tmux display-message -p "#{window_id}")"

      while IFS= read -r pane_line; do
        local pane_id pane_cmd pane_pid
        pane_id="$(awk '{print $1}' <<<"$pane_line")"
        pane_cmd="$(awk '{print $2}' <<<"$pane_line")"
        pane_pid="$(awk '{print $3}' <<<"$pane_line")"

        if is_tool "opencode" "$pane_cmd" "$pane_pid" || is_tool "oc" "$pane_cmd" "$pane_pid"; then
          oc_icons+=$(icon_for "$(detect_state "$pane_id")")
        elif is_tool "claude" "$pane_cmd" "$pane_pid"; then
          cc_icons+=$(icon_for "$(detect_state "$pane_id")")
        fi
      done < <(tmux list-panes -t "$win_id" -F "#{pane_id} #{pane_current_command} #{pane_pid}")

      local out=""
      [[ -n "$oc_icons" ]] && out+="OC:$oc_icons"
      if [[ -n "$cc_icons" ]]; then
        if [[ -n "$out" ]]; then
          out+=" CC:$cc_icons"
        else
          out+="CC:$cc_icons"
        fi
      fi

      # Print nothing when irrelevant (keeps status-right clean).
      [[ -n "$out" ]] && printf " %s" "$out"
      exit 0
    }

    main
  '';

  # Fetch tmux-dotbar - minimal dot-separated status bar theme
  tmux-dotbar = pkgs.fetchFromGitHub {
    owner = "vaaleyard";
    repo = "tmux-dotbar";
    rev = "f62692501114582aa5311158271ec39402dfcbcd";
    sha256 = "0y9hjw5rxr3684dcg8s5qc7r70p1ai39bjbadmn7vlnn6680qjzy";
  };

  # Fetch tmux-smooth-scroll plugin for animated scrolling
  tmux-smooth-scroll = pkgs.fetchFromGitHub {
    owner = "azorng";
    repo = "tmux-smooth-scroll";
    rev = "4c1232796235173f3e48031cbffe4a19773a957a";
    sha256 = "sha256-nTB0V/Xln8QJ95TB+hpIbuf0GwlBCU7CFQyzd0oWXw4=";
  };

  # Despite tmux/tmux#142, tmux will support XDG in 3.2. Sadly, only 3.0 is
  # available on nixpkgs, and 3.1b on master (tmux/tmux@15d7e56), so I
  # implement it myself:
  # Export environment variables with fallback defaults for when they aren't
  # set (e.g., ghostty launching with --noprofile --norc). These are needed
  # by the tmux config file itself for sourcing extraInit, swap-pane scripts,
  # and the reload binding.
  tmux = pkgs.writeScriptBin "tmux" ''
    #!${pkgs.stdenv.shell}
    export TMUX_HOME="''${TMUX_HOME:-$HOME/.config/tmux}"
    export DOTFILES="''${DOTFILES:-$HOME/.config/dotfiles}"
    export DOTFILES_BIN="''${DOTFILES_BIN:-$DOTFILES/bin}"
    exec ${pkgs.tmux}/bin/tmux -f "$TMUX_HOME/config" "$@"
  '';
in
{
  options.modules.shell.tmux = with types; {
    enable = mkBoolOpt false;
    rcFiles = mkOpt (listOf (either str path)) [ "${configDir}/tmux/theme.conf" ];
  };

  config = mkIf cfg.enable {
    user.packages = [
      tmux
      pkgs.my.tmux-file-picker
      pkgs.gum # Interactive CLI for bd-capture popup
    ];

    modules.theme.onReload.tmux = "${tmux}/bin/tmux source-file $TMUX_HOME/extraInit";

    modules.shell.zsh = {
      rcInit = "_cache tmuxifier init -";
      rcFiles = [ "${configDir}/tmux/aliases.zsh" ];
    };

    home.configFile = {
      "tmux" = {
        source = "${configDir}/tmux";
        recursive = true;
      };
      "tmux/extraInit".text = ''
        # This file is auto-generated by nixos, don't edit by hand!

        # Load theme config FIRST (sets dotbar color options and pane/border styling)
        # Must happen before dotbar.tmux runs to pick up @tmux-dotbar-* options
        ${concatMapStrings (path: ''
          source '${path}'
        '') cfg.rcFiles}

        # Dotbar theme (must run before prefix-highlight)
        run-shell ${tmux-dotbar}/dotbar.tmux

        # Plugins (prefix-highlight can now replace #{prefix_highlight} placeholder)
        run-shell ${pkgs.tmuxPlugins.copycat}/share/tmux-plugins/copycat/copycat.tmux
        run-shell ${pkgs.tmuxPlugins.prefix-highlight}/share/tmux-plugins/prefix-highlight/prefix_highlight.tmux
        run-shell ${pkgs.tmuxPlugins.yank}/share/tmux-plugins/yank/yank.tmux
        set-option -ga status-right "#(${opencodeStatus})"
        run-shell ${tmux-smooth-scroll}/smooth-scroll.tmux

        # tmux-opencode-integrated: smart naming + OpenCode status
        run-shell ${pkgs.my.tmux-opencode-integrated}/share/tmux-plugins/tmux-opencode-integrated/scripts/smart-name.sh
      '';
    };

    env = {
      PATH = [ "$TMUXIFIER/bin" ];
      TMUX_HOME = "$XDG_CONFIG_HOME/tmux";
      TMUXIFIER = "$XDG_DATA_HOME/tmuxifier";
      TMUXIFIER_LAYOUT_PATH = "$XDG_DATA_HOME/tmuxifier";
    };
  };
}
