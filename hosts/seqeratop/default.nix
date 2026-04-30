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
        tmux.jmux.enable = true;
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

        # Keep macOS Terminal.app aligned with host-specific font and Seqera colors.
        # Creates/updates a "Seqera" profile and sets it as startup/default profile.
        home.activation.setTerminalSeqeraProfile = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
          if [ -x /usr/bin/osascript ]; then
            /usr/bin/osascript <<'APPLESCRIPT' >/dev/null 2>&1 || true
            tell application "Terminal"
              -- Ensure profile exists (duplicate Basic once)
              if not (exists settings set "Seqera") then
                set newProfile to (make new settings set with properties {name:"Seqera"})
                set baseProfile to settings set "Basic"
                set font name of newProfile to font name of baseProfile
                set font size of newProfile to font size of baseProfile
              end if

              set seqeraProfile to settings set "Seqera"

              -- Font
              set font name of seqeraProfile to "JetBrainsMono-Regular"
              set font size of seqeraProfile to 14

              -- Seqera colors
              set background color of seqeraProfile to {8224, 5654, 14135} -- #201637
              set normal text color of seqeraProfile to {58082, 63479, 62451} -- #e2f7f3
              set bold text color of seqeraProfile to {65535, 65535, 65535} -- #ffffff
              set cursor color of seqeraProfile to {12593, 51657, 44204} -- #31c9ac
              set selection color of seqeraProfile to {1542, 22102, 18247} -- #065647

              -- Make this profile the default for new windows/tabs
              set default settings to seqeraProfile
              set startup settings to seqeraProfile
            end tell
            APPLESCRIPT
          fi
        '';
      };

  };
}
