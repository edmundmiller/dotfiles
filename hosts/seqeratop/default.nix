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
        claude.enable = true;
        codex.enable = true;
        opencode.enable = true;
        pi.enable = true;
        skillkit.enable = true;
        pi.memoryRemote = "git@github.com:edmundmiller/pi-memory";
        direnv.enable = true;
        git.enable = true;
        git.ai.enable = true;
        jj.enable = true;
        tmux.enable = true;
        tmux.opensessions.enable = true;
        dmux.enable = true;
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

      services = {
        obsidian-sync.enable = false;
        docker.enable = true;
        ssh.enable = true;
      };

      desktop.macos.enable = true;

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

      onActivation = {
        extraFlags = [ "--quiet" ]; # Reduce Homebrew activation chatter
      };
    }
    // (import ./homebrew.nix);

    environment.systemPackages = with pkgs; [
      llm-agents.qmd
    ];

    home-manager.users.${config.user.name} =
      { lib, ... }:
      {
        home.activation.removeLegacyQmd = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
          rm -f "$HOME/.bun/bin/qmd" "$HOME/.cache/npm/bin/qmd"
        '';
      };

  };
}
