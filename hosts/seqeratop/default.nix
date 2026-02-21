_: {
  config = {
    modules = {
      editors = {
        default = "nvim";
        emacs.enable = true;
        vim.enable = true;
      };
      dev = {
        node.enable = true;
        node.useFnm = true;
        python.enable = true;
        python.conda.enable = true;
        R.enable = true;
      };

      shell = {
        "1password".enable = true;
        ai.enable = true;
        claude.enable = true;
        codex.enable = true;
        opencode.enable = true;
        pi.enable = true;
        direnv.enable = true;
        git.enable = true;
        jj.enable = true;
        tmux.enable = true;
        wt.enable = true;
        zsh.enable = true;
      };

      services = {
        docker.enable = true;
        ssh.enable = true;
      };

      macos-defaults.enable = true;

      desktop = {
        term.ghostty.enable = true;
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
    }
    // (import ./homebrew.nix);


  };
}
