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
    # Use homebrew to install casks and Mac App Store apps
    homebrew = {
      enable = true;

      casks = [
        "1password"
        "1password-cli"
        "bartender"
        "raycast"
        "soundsource"
        "ghostty"
        "font-jetbrains-mono"
        "font-juliamono"
        "slack"
        "aerospace"
        "spotify"
        # "amethyst"
        "gitify"
        "subler"
        "sunsama"

        "microsoft-teams"
        "visual-studio-code"
        "claude"
        "vlc"
        "discord"
        "orion"
        "font-ia-writer-duo"
        "zoom"
      ];

      #   masApps = {
      #     "Drafts" = 1435957248;
      #     "Reeder" = 1529448980;
      #     "Things" = 904280696;
      #     "Timery" = 1425368544;
      #   };
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
        # AppleKeyboardUIMode = 3;
        "com.apple.keyboard.fnState" = false;
      };
    };
  };
}
