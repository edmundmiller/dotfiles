{ config, pkgs, inputs, ... }:
{
  config = {
    # Hostname for per-host secrets (Darwin doesn't have networking.hostName)

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
        # FIXME: Conflicts with Homebrew 1password@beta cask - using Homebrew for now
        "1password".enable = false;
        ai.enable = true;
        bugwarrior = {
          enable = true;
          flavor = "personal";
        };
        claude.enable = true;
        direnv.enable = true;
        git.enable = true;
        jj.enable = true;
        opencode.enable = true;
        ssh.enable = true;
        taskwarrior = {
          enable = true;
          syncUrl = "http://nuc.cinnamon-rooster.ts.net:8080";
        };
        prise.enable = true;
        tmux.enable = true;
        try.enable = true;
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
        autoUpdate = true;
        cleanup = "zap";
        upgrade = true;
      };
    } // (import ./homebrew.nix);

    # Override the primary user for this host
    system.primaryUser = "emiller";

    # Additional system packages
    # NOTE: jj-spr temporarily disabled - upstream has broken cargo vendoring after flake update
    environment.systemPackages = [ ];

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
        # TODO: persistent-apps disabled due to nix-darwin type issue
        # See: https://github.com/nix-darwin/nix-darwin/issues/1428
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
