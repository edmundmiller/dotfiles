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
        node.bunGlobalPackages = [
          "critique@0.1.139"
        ];
        # FIXME: Python disabled - bundled whisper currently includes Python 3.13
        # Conflicts with python module's withPackages env. See dotfiles-c11.
        python.enable = false;
        python.conda.enable = false;
      };

      shell = {
        "1password".enable = true;
        ai.enable = true;
        amoxide.enable = true;
        agentBrowser.enable = true;
        direnv.enable = true;
        git.enable = true;
        git.ai.enable = true;
        git.hunk.enable = true;
        git.lazydiff.enable = true;
        jj.enable = true;
        tmux.enable = true;
        acpx.enable = true;
        herdr.enable = true;
        tmux.jmux.enable = true;
        tmux.jmux.package = pkgs.my.jmux;
        tmux.jmux.configFile = "${config.dotfiles.configDir}/jmux/config.json";
        tmux.opensessions.enable = true;
        tmux.experimental.sessionDots.enable = true;
        tmux.experimental.agentStatus.enable = true;
        dmux.enable = false;
        zsh.enable = true;
      };

      agents = {
        hermes = {
          enable = true;
          honcho.enable = true;
          secretReferences = {
            HONCHO_API_KEY = "op://Private/Honcho Admin key/credential";
            OPENCODE_GO_API_KEY = "op://Agents/MTP OpenCode Go/credential";
            OPENROUTER_API_KEY = "op://Agents/MTP OpenRouter/credential";
            HASS_TOKEN = "op://Agents/Hermes Laptop HA/credential";
            HA_TOKEN = "op://Agents/Hermes Laptop HA/credential";
          };
        };
        pi = {
          enable = true;
          honcho = {
            enable = true;
            workspace = "coding";
            peerName = "edmundmiller";
            aiPeer = "pi";
            sessionStrategy = "directory";
          };
          secretReferences = {
            HONCHO_API_KEY = "op://Private/Honcho Admin key/credential";
            OPENCODE_GO_API_KEY = "op://Agents/MTP OpenCode Go/credential";
          };
        };
        claude.enable = true;
        codex.enable = true;
        opencode.enable = true;
      };

      services = {
        obsidian-sync.enable = false;
        docker.enable = true;
        tailscale.enable = true;
        ssh.enable = true;
        kittylitter = {
          enable = true;
          enabledAgents = [
            "pi"
            "amp"
          ];
        };
      };

      desktop.macos.enable = true;

      desktop = {
        apps.raycast.enable = true;
        apps.audioPriorityBar.enable = true;
        apps.handy.enable = true;
        term.ghostty.enable = true;
      };

      # Stylix: Catppuccin Mocha matches the existing Pi/Herdr theme on this host.
      # No real wallpaper here yet — the module mints a solid-color placeholder
      # PNG (base00) so stylix is happy without committing a binary asset.
      theme.stylix = {
        enable = true;
        polarity = "auto";
        schemeName = "catppuccin-mocha";
        fallbackImageColor = "1e1e2e"; # catppuccin mocha base00
      };
    };

    # Configure nix-homebrew for proper privilege management
    nix-homebrew = {
      enable = true;
      user = "emiller";
      enableRosetta = false; # ARM-only Homebrew on this host; no Intel prefix management needed now.
      autoMigrate = true; # Migrate existing homebrew installation
      mutableTaps = true; # Allow mutable taps for flexibility
      enableZshIntegration = false; # We handle brew in .zshenv with caching
    };

    # Manage native macOS Login Items declaratively. Keep Raycast Beta here and
    # do not also start it with a launchd.user.agent, or macOS will run two instances.
    environment.loginItems = {
      enable = true;
      items = [
        "/Applications/Raycast Beta.app"
        "/Applications/1Password.app"
        "/Applications/CleanShot X.app"
        "/Applications/LookAway.app"
        "/Applications/Monologue.app"
      ];
    };

    # Use homebrew to install casks and Mac App Store apps
    homebrew = {
      enable = true;

      # Homebrew configuration
      onActivation = {
        autoUpdate = false; # Don't auto-update during activation
        cleanup = "none"; # Don't remove anything for now
        upgrade = false; # Don't upgrade formulae during activation
        extraEnv = {
          # Work around Homebrew API cask JSON bugs by using local tap files
          # during nix-darwin activation. Supported directly by newer nix-darwin.
          HOMEBREW_NO_INSTALL_FROM_API = "1";
        };
        extraFlags = [ "--quiet" ]; # Reduce Homebrew activation chatter
      };
    }
    // import ./homebrew.nix;

    # Override the primary user for this host
    system.primaryUser = "emiller";

    # Add desktop helpers + qmd CLI
    environment.systemPackages = with pkgs; [
      llm-agents.qmd
      my.zele
      my.worktree-manager
    ];

    home-manager.users.${config.user.name} =
      { lib, ... }:
      {
        home.sessionVariables = {
          PI_MODEL_SWITCH_INTENT = "opencode-go/kimi-2.5";
          PI_MODEL_SWITCH_CODING = "openai-codex/gpt-5.3-codex";
          PI_MODEL_SWITCH_DONE = "opencode-go/kimi-2.5";
        };

        home.activation.removeLegacyQmd = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
          rm -f "$HOME/.bun/bin/qmd" "$HOME/.cache/npm/bin/qmd"
        '';

        home.activation.removeLegacyZele = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
          rm -f "$HOME/.bun/bin/zele" "$HOME/.cache/npm/bin/zele"
        '';

        # Keep the Seqera work wallpaper in a stable location and apply it to the desktop.
        # macOS wallpaper automation reliably accepts the PNG export; the SVG sibling
        # does not consistently stick as a desktop picture when scripted.
        # After setting the image, force Sonoma/Sequoia wallpaper placement to Centered
        # so the icon stays small and doesn't stretch.
        home.activation.setSeqeraWallpaper = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
          wallpaper_src="$HOME/Downloads/seqera 6/seqera_no_margin/pngs/Seqera Icon Light Green.png"
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
              "${config.dotfiles.binDir}/macos-wallpaper-placement.py" \
              "$wallpaper_store" \
              Centered \
              201637
            killall WallpaperAgent >/dev/null 2>&1 || true
          fi
        '';
      };

    # TODO(dotfiles-lbea): Remove this shim cleanup block after a few rebuild cycles once
    # we're confident no machines/users still carry legacy /usr/local/bin/brew links.
    # Cleanup legacy Intel brew shim if it still exists from older Rosetta-enabled setups.
    system.activationScripts.cleanupLegacyIntelBrew.text = ''
      if [ -L "/usr/local/bin/brew" ]; then
        rm -f /usr/local/bin/brew
      fi
    '';

    # Enable sudo authentication with Touch ID.
    security.pam.services.sudo_local.touchIdAuth = true;

    # Passwordless sudo for darwin-rebuild (enables agent-driven rebuilds)
    security.sudo.extraConfig = ''
      emiller ALL=(root) NOPASSWD: /run/current-system/sw/bin/darwin-rebuild *
    '';

  };
}
