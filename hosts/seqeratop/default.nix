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
      desktop.term.ghostty.enable = true;
      desktop.term.kitty.enable = true;

      shell = {
        "1password".enable = true;
        ai.enable = true;
        bugwarrior = {
          enable = true;
          flavor = "work";
        };
        claude.enable = true;
        direnv.enable = true;
        git.enable = true;
        jj.enable = true;
        opencode.enable = true;
        taskwarrior = {
          enable = true;
          syncUrl = "http://192.168.1.222:8080";
          defaultContext = "work";
        };
        tmux.enable = true;
        try.enable = true;
        zsh.enable = true;
      };

      services = {
        docker.enable = true;
        ssh.enable = true;
      };
    };

    # Override the primary user for this host
    system.primaryUser = "edmundmiller";
    user.name = "edmundmiller";

    # Additional system packages
    # NOTE: jj-spr temporarily disabled - upstream has broken cargo vendoring after flake update
    # environment.systemPackages = with pkgs; [
    #   (inputs.jj-spr.packages.${pkgs.stdenv.hostPlatform.system}.default.overrideAttrs (old: {
    #     buildInputs = (old.buildInputs or []) ++ [ zlib ];
    #   }))
    # ];
    environment.systemPackages = [ ];

    # Configure nix-homebrew for proper privilege management
    nix-homebrew = {
      enable = true;
      user = "edmundmiller";
      enableRosetta = true;  # Apple Silicon + Intel compatibility
      autoMigrate = true;    # Migrate existing homebrew installation
    };

    # Use homebrew to install casks and Mac App Store apps
    homebrew = {
      enable = true;

      taps = [
        # "rockorager/tap"  # Prise terminal multiplexer
      ];
      brews = [
        "duckdb"
        # "rockorager/tap/prise"  # Modern terminal multiplexer
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

        # Task management
        "rlwrap"
        "task"
        "taskopen"
        "tasksh"
        "taskwarrior-tui"
        "timewarrior"
        "opencode"
      ];
      casks = [
        "1password-cli"
        "spotify"
        "bartender"
        "sunsama"

        "repo-prompt"
        "font-jetbrains-mono"
        "positron"
        "ghostty"
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
