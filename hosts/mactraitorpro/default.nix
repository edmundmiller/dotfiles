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
    # Use homebrew to install casks and Mac App Store apps
    homebrew = {
      enable = true;

      taps = [ "jimeh/emacs-builds" ];
      brews = [
        "duckdb"
        "gh"
        "fzf"
        "neovim"
        "ruff"
        "uv"
        "seqeralabs/tap/wave-cli"
        "tldr"
        # Doom
        "git"
        "ripgrep"
        "coreutils"
        "fd"
        "tree-sitter"
      ];
      casks = [
        "1password"
        "1password-cli"
        "bartender"
        "boltai"
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

        "emacs-app-pretest"
        "mendeley-reference-manager"
        "microsoft-teams"
        "visual-studio-code"
        "claude"
        "vlc"
        "discord"
        "orion"
        "font-ia-writer-duo"
        "vivaldi"
        "zen-browser"
        "zoom"
      ];

      masApps = {
        "Keynote" = 409183694;
        "Numbers" = 409203825;
        "Xcode" = 497799835;
      };
    };

    # Enable sudo authentication with Touch ID.
    security.pam.enableSudoTouchIdAuth = true;

    # set some OSX preferences that I always end up hunting down and changing.
    system.defaults = {
      # minimal dock
      dock = {
        autohide = true;
        orientation = "left";
        show-process-indicators = false;
        show-recents = false;
        static-only = true;
        # TODO: Make this user-specific
        # "/Users/${username}/Applications/Home Manager Apps/Telegram.app"
        persistent-apps = [
          # "/Applications/Brave Browser.app"
          # "/Applications/Wavebox.app"
          # "/Users/edmundmiller/Applications/Home Manager Apps/Telegram.app"
          # "/Users/edmundmiller/Applications/Home Manager Apps/Discord.app"
          # "/Users/edmundmiller/Applications/Home Manager Apps/Cinny.app"
          # "/Applications/Halloy.app"
          # "/Users/edmundmiller/Applications/Home Manager Apps/Visual Studio Code.app"
          # "/Users/edmundmiller/Applications/Home Manager Apps/GitKraken.app"
          # "/Users/edmundmiller/Applications/Home Manager Apps/Alacritty.app"
          # "/System/Applications/Music.app"
          # "/Applications/Heynote.app"
          # "/Applications/Joplin.app"
          # "/System/Applications/Launchpad.app"
        ];
        tilesize = 36;
        # Disable hot corners
        wvous-bl-corner = 1;
        wvous-br-corner = 1;
        wvous-tl-corner = 1;
        wvous-tr-corner = 1;
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
