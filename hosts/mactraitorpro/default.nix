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
      };
      dev = {
        node.enable = true;
        node.useFnm = true;
        node.bunGlobalPackages = [
          "hunkdiff@0.9.1"
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
        agentBrowser.enable = true;
        direnv.enable = true;
        git.enable = true;
        git.ai.enable = true;
        jj.enable = true;
        tmux.enable = true;
        tmux.opensessions.enable = true;
        dmux.enable = true;
        zsh.enable = true;
      };

      agents = {
        hermes = {
          enable = true;
          honcho.enable = true;
          secretReferences = {
            HONCHO_API_KEY = "op://Agents/MTP Honcho/credential";
            OPENCODE_GO_API_KEY = "op://Agents/OPENCODE_GO_API_KEY/credential";
            OPENROUTER_API_KEY = "op://Agents/MTP OpenRouter/credential";
          };
        };
        pi = {
          enable = true;
          honcho.enable = true;
          secretReferences = {
            HONCHO_API_KEY = "op://Agents/MTP Honcho/credential";
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
        tailscale.enable = true;
        ssh.enable = true;
      };

      desktop.macos.enable = true;

      desktop = {
        apps.raycast.enable = true;
        term.ghostty.enable = true;
      };
    };

    # Configure nix-homebrew for proper privilege management
    nix-homebrew = {
      enable = true;
      user = "emiller";
      enableRosetta = true; # Apple Silicon + Intel compatibility
      autoMigrate = true; # Migrate existing homebrew installation
      mutableTaps = true; # Allow mutable taps for flexibility
      enableZshIntegration = false; # We handle brew in .zshenv with caching
    };

    # Use homebrew to install casks and Mac App Store apps
    homebrew = {
      enable = true;

      # Homebrew configuration
      onActivation = {
        autoUpdate = false; # Don't auto-update during activation
        cleanup = "none"; # Don't remove anything for now
        upgrade = false; # Don't upgrade formulae during activation
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
    ];

    home-manager.users.${config.user.name} =
      { lib, ... }:
      {
        xdg.configFile."hunk/config.toml".text = ''
          theme = "graphite"
          mode = "auto"
          line_numbers = true
          wrap_lines = false
          agent_notes = true
        '';

        home.activation.removeLegacyQmd = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
          rm -f "$HOME/.bun/bin/qmd" "$HOME/.cache/npm/bin/qmd"
        '';

        home.activation.removeLegacyZele = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
          rm -f "$HOME/.bun/bin/zele" "$HOME/.cache/npm/bin/zele"
        '';
      };

    # Prevent Intel brew symlink from being created
    system.activationScripts.removeIntelBrew.text = ''
      echo "Ensuring Intel brew symlink doesn't conflict with ARM homebrew..."
      if [ -L "/usr/local/bin/brew" ]; then
        echo "Removing Intel brew symlink to prevent ARM/Intel conflicts"
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
