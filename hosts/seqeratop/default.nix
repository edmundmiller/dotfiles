{ config, ... }:
{
  config = {
    modules = {
      editors = {
        default = "nvim";
        emacs.enable = true;
        vim.enable = true;
      };
      dev = {
        python.enable = true;
        python.conda.enable = true;
        R.enable = true;
      };

      shell = {
        "1password".enable = true;
        ai.enable = true;
        claude.enable = true;
        direnv.enable = true;
        git.enable = true;
        tmux.enable = true;
        zsh.enable = true;
      };

      services = {
        docker.enable = true;
        ssh.enable = true;
      };
    };

    # Override the primary user for this host
    system.primaryUser = "edmundmiller";

    # Configure nix-homebrew for proper privilege management
    nix-homebrew = {
      enable = true;
      user = "edmundmiller";
      enableRosetta = true;  # Apple Silicon + Intel compatibility
      autoMigrate = true;    # Migrate existing homebrew installation
      mutableTaps = true;    # Allow mutable taps for flexibility
    };

    # Use homebrew to install casks and Mac App Store apps
    homebrew = {
      enable = true;

      # TODO taps = [ "d12frosted/emacs-plus" ];
      brews = [
        "duckdb"
        "dvc"
        "gh"
        "fzf"
        "neovim"
        "ruff"
        "uv"
        "tealdeer"
        "seqeralabs/tap/tw"
        "seqeralabs/tap/wave-cli"
        "pulumi/tap/pulumi"
        "awscli"
        # Doom
        "git"
        "ripgrep"
        "coreutils"
        "fd"
        # Doom Extra
        "tree-sitter"
      ];
      casks = [
        "1password-cli"
        "spotify"
        "bartender"
        "sunsama"

        "repo-prompt"
        "font-jetbrains-mono"
        "positron"
        "ghostty@tip"
        "raycast"
        "claude"
        "gitify"
        "soundsource"
      ];
      masApps = {
        "Xcode" = 497799835;
      };
    };

    # set some OSX preferences that I always end up hunting down and changing.
    system.defaults = {
      # minimal dock
      dock = {
        autohide = true;
        orientation = "left";
        show-process-indicators = false;
        show-recents = false;
        static-only = true;
      };
      # a finder that tells me what I want to know and lets me work
      finder = {
        AppleShowAllExtensions = true;
        ShowPathbar = true;
        FXEnableExtensionChangeWarning = false;
      };
      # Tab between form controls and F-row that behaves as F1-F12
      NSGlobalDomain = {
        AppleKeyboardUIMode = 3;
        "com.apple.keyboard.fnState" = false;
      };
    };
  };
}
