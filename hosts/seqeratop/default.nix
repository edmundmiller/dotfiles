{
  config,
  pkgs,
  ...
}:
{
  config = {
    modules = {
      editors = {
        default = "nvim";
        emacs.enable = true;
        vim.enable = true;
        zed.enable = true;
        file-associations = {
          enable = true;
          editor = "zed";
        };
      };
      dev = {
        node.enable = true;
        node.useFnm = true;
        python.enable = true;
        python.conda.enable = true;
      };

      shell = {
        "1password".enable = true;
        ai.enable = true;
        amoxide.enable = true;
        skillkit.enable = true;
        direnv.enable = true;
        git.enable = true;
        git.ai.enable = true;
        jj.enable = true;
        tmux.enable = true;
        tmux.jmux.enable = false;
        herdr.enable = true;
        tmux.jmux.configFile = "${config.dotfiles.configDir}/jmux/config.json";
        tmux.opensessions.enable = true;
        dmux.enable = false;
        tmux.sesh.sessions = [
          {
            name = "dotfiles";
            path = "~/.config/dotfiles";
          }
          {
            name = "platform";
            path = "~/src/seqera/platform";
          }
          {
            name = "nf-core";
            path = "~/src/nf-core";
          }
          {
            name = "nextflow";
            path = "~/src/nextflow/nextflow";
          }
          {
            name = "nf-xpack";
            path = "~/src/seqera/nf-xpack";
          }
          {
            name = "portal";
            path = "~/src/seqera/portal";
          }
          {
            name = "portal-main";
            path = "~/src/seqera/portal/main";
          }
          {
            name = "scientific-engagement";
            path = "~/src/seqera/scientific-engagment";
          }
        ];
        zsh.enable = true;
      };

      agents = {
        pi = {
          enable = true;
          secretReferences = {
            OPENCODE_GO_API_KEY = "op://Agents/MTP OpenCode Go/credential";
          };
          memoryRemote = "git@github.com:edmundmiller/pi-memory";
        };
        claude.enable = true;
        codex.enable = true;
        opencode.enable = true;
      };

      services = {
        obsidian-sync.enable = false;
        docker.enable = true;
        ssh.enable = true;
      };

      desktop.macos.enable = true;

      desktop = {
        apps.audioPriorityBar.enable = true;
        apps.handy.enable = true;
        term.ghostty = {
          enable = true;
          # Host-specific Seqera brand themes (auto-switch with system appearance)
          # plus host-local font override.
          configInit = ''
            font-family = JetBrains Mono
            font-size = 14
            theme = dark:SeqeraDark,light:SeqeraLight
          '';
        };
      };
    };

    # Override the primary user for this host
    system.primaryUser = "edmundmiller";

    # Configure nix-homebrew for proper privilege management
    nix-homebrew = {
      enable = true;
      user = "edmundmiller";
      enableRosetta = true; # Apple Silicon + Intel compatibility
      autoMigrate = true; # Migrate existing homebrew installation
      mutableTaps = true; # Allow mutable taps for flexibility
    };

    # Use homebrew to install casks and Mac App Store apps
    homebrew = {
      enable = true;

      onActivation = {
        extraFlags = [ "--quiet" ]; # Reduce Homebrew activation chatter
      };
    }
    // (import ./homebrew.nix);

    environment.systemPackages = with pkgs; [
      llm-agents.qmd
      my.zele
    ];

    home-manager.users.${config.user.name} =
      { lib, ... }:
      {
        home.sessionVariables = {
          PI_MODEL_SWITCH_INTENT = "openai-codex/gpt-5.4";
          PI_MODEL_SWITCH_CODING = "openai-codex/gpt-5.3-codex";
          PI_MODEL_SWITCH_DONE = "openai-codex/gpt-5.4";
        };

        # Host-local Ghostty themes in Seqera brand colors.
        xdg.configFile."ghostty/themes/SeqeraDark".source =
          "${config.dotfiles.configDir}/ghostty/themes/SeqeraDark";
        xdg.configFile."ghostty/themes/SeqeraLight".source =
          "${config.dotfiles.configDir}/ghostty/themes/SeqeraLight";

        home.activation.removeLegacyQmd = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
          rm -f "$HOME/.bun/bin/qmd" "$HOME/.cache/npm/bin/qmd"
        '';

        # Keep the Seqera work wallpaper in a stable location and apply it to the desktop.
        # macOS wallpaper automation reliably accepts the PNG export; the SVG sibling
        # does not consistently stick as a desktop picture when scripted.
        # After setting the image, force Sonoma/Sequoia wallpaper placement to Centered
        # so the icon stays small and doesn't stretch.
        home.activation.setSeqeraWallpaper = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
          wallpaper_src='/Users/edmundmiller/Downloads/seqera 6/seqera_no_margin/pngs/Seqera Icon Light Green.png'
          wallpaper_dst="$HOME/Pictures/Wallpapers/Seqera Icon Light Green.png"
          wallpaper_store="$HOME/Library/Application Support/com.apple.wallpaper/Store/Index.plist"

          mkdir -p "$(dirname "$wallpaper_dst")"
          if [ -f "$wallpaper_src" ]; then
            cp -f "$wallpaper_src" "$wallpaper_dst"
          fi

          if [ -f "$wallpaper_dst" ] && [ -x /usr/bin/osascript ]; then
            wallpaper_escaped=$(printf '%s' "$wallpaper_dst" | sed 's/\\/\\\\/g; s/"/\\"/g')
            /usr/bin/osascript -e "tell application \"Finder\" to set desktop picture to POSIX file \"$wallpaper_escaped\"" >/dev/null 2>&1 || true
          fi

          if [ -f "$wallpaper_store" ]; then
            "${pkgs.python3}/bin/python3" \
              "${config.dotfiles.configDir}/bin/macos-wallpaper-placement.py" \
              "$wallpaper_store" \
              Centered \
              201637
            killall WallpaperAgent >/dev/null 2>&1 || true
          fi
        '';

        # Keep macOS Terminal.app aligned with host-specific font and Seqera colors.
        # Creates/updates a "Seqera" profile and sets it as startup/default profile.
        home.activation.setTerminalSeqeraProfile = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
          if [ -x /usr/bin/osascript ]; then
            /usr/bin/osascript \
              -e 'tell application "Terminal"' \
              -e 'try' \
              -e 'make new settings set with properties {name:"Seqera"}' \
              -e 'end try' \
              -e 'set font name of settings set "Seqera" to "JetBrainsMono-Regular"' \
              -e 'set font size of settings set "Seqera" to 14' \
              -e 'set background color of settings set "Seqera" to {8224, 5654, 14135}' \
              -e 'set normal text color of settings set "Seqera" to {58082, 63479, 62451}' \
              -e 'set bold text color of settings set "Seqera" to {65535, 65535, 65535}' \
              -e 'set cursor color of settings set "Seqera" to {12593, 51657, 44204}' \
              -e 'try' \
              -e 'set selection color of settings set "Seqera" to {1542, 22102, 18247}' \
              -e 'end try' \
              -e 'set default settings to settings set "Seqera"' \
              -e 'set startup settings to settings set "Seqera"' \
              -e 'if (count of windows) > 0 then' \
              -e 'repeat with w in windows' \
              -e 'repeat with t in tabs of w' \
              -e 'set current settings of t to settings set "Seqera"' \
              -e 'end repeat' \
              -e 'end repeat' \
              -e 'end if' \
              -e 'end tell' >/dev/null 2>&1 || true
          fi
        '';
      };

  };
}
