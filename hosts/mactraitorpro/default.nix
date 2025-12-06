{ config, pkgs, inputs, ... }:
{
  config = {
    modules = {
      editors = {
        default = "nvim";
        emacs.enable = true;
        vim.enable = true;
        file-associations = {
          enable = true;
          editor = "zed";
        };
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
        jj.enable = true;
        tmux.enable = true;
        zsh.enable = true;
      };

      desktop.term.ghostty.enable = true;
      desktop.term.kitty.enable = true;

      services = {
        docker.enable = true;
        ssh.enable = true;
      };
    };

    # Configure nix-homebrew for proper privilege management
    nix-homebrew = {
      enable = true;
      user = "emiller";
      enableRosetta = true;  # Apple Silicon + Intel compatibility
      autoMigrate = true;    # Migrate existing homebrew installation
    };

    # Use homebrew to install casks and Mac App Store apps
    homebrew = {
      enable = true;

      # Homebrew configuration
      onActivation = {
        autoUpdate = false;  # Don't auto-update during activation
        cleanup = "none";     # Don't remove anything for now
        upgrade = false;     # Don't upgrade formulae during activation
      };
    } // (import ./homebrew.nix);

    # Override the primary user for this host
    system.primaryUser = "emiller";

    # Additional system packages
    environment.systemPackages = with pkgs; [
      (inputs.jj-spr.packages.${pkgs.stdenv.hostPlatform.system}.default.overrideAttrs (old: {
        buildInputs = (old.buildInputs or []) ++ [ zlib ];
      }))
    ];

    # Enable sudo authentication with Touch ID.
    security.pam.services.sudo_local.touchIdAuth = true;

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
