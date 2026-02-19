{
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
        node.bunGlobalPackages = [ "zele" ];
        # FIXME: Python disabled - openclaw bundles whisper which includes Python 3.13
        # Conflicts with python module's withPackages env. See dotfiles-c11.
        python.enable = false;
        python.conda.enable = false;
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
        tml.enable = true;
        tmux.enable = true;
        wt.enable = true;
        zsh.enable = true;
      };

      services = {
        openclaw.enable = false;
        docker.enable = true;
        ssh.enable = true;
      };

      desktop = {
        apps.raycast.enable = true;
        apps.openclaw.enable = true;
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
    };

    # Use homebrew to install casks and Mac App Store apps
    homebrew = {
      enable = true;

      # Homebrew configuration
      onActivation = {
        autoUpdate = false; # Don't auto-update during activation
        cleanup = "none"; # Don't remove anything for now
        upgrade = false; # Don't upgrade formulae during activation
      };
    }
    // import ./homebrew.nix;

    # Override the primary user for this host
    system.primaryUser = "emiller";

    # Add duti for managing file associations
    environment.systemPackages = with pkgs; [
      duti
    ];

    # Prevent Intel brew symlink from being created
    system.activationScripts.removeIntelBrew.text = ''
      echo "Ensuring Intel brew symlink doesn't conflict with ARM homebrew..."
      if [ -L "/usr/local/bin/brew" ]; then
        echo "Removing Intel brew symlink to prevent ARM/Intel conflicts"
        rm -f /usr/local/bin/brew
      fi
    '';

    # Create a duti configuration file and apply it on activation
    system.activationScripts.dutiConfiguration.text = ''
      echo "Configuring default text editor file associations..."

      # Create duti configuration
      cat > /tmp/duti-config.txt <<EOF
      # Zed as default text editor
      # Format: bundle_id UTI role

      # Text files
      dev.zed.Zed public.plain-text all
      dev.zed.Zed public.text all
      dev.zed.Zed public.source-code all
      dev.zed.Zed public.script all
      dev.zed.Zed public.shell-script all
      dev.zed.Zed public.python-script all
      dev.zed.Zed public.ruby-script all
      dev.zed.Zed public.perl-script all
      dev.zed.Zed public.json all
      dev.zed.Zed public.xml all
      dev.zed.Zed public.html all
      dev.zed.Zed com.netscape.javascript-source all
      dev.zed.Zed net.daringfireball.markdown all

      # File extensions
      dev.zed.Zed .txt all
      dev.zed.Zed .md all
      dev.zed.Zed .markdown all
      dev.zed.Zed .nix all
      dev.zed.Zed .log all
      dev.zed.Zed .conf all
      dev.zed.Zed .config all
      dev.zed.Zed .toml all
      dev.zed.Zed .yaml all
      dev.zed.Zed .yml all
      dev.zed.Zed .json all
      dev.zed.Zed .js all
      dev.zed.Zed .ts all
      dev.zed.Zed .jsx all
      dev.zed.Zed .tsx all
      dev.zed.Zed .py all
      dev.zed.Zed .rb all
      dev.zed.Zed .sh all
      dev.zed.Zed .bash all
      dev.zed.Zed .zsh all
      dev.zed.Zed .fish all
      dev.zed.Zed .c all
      dev.zed.Zed .h all
      dev.zed.Zed .cpp all
      dev.zed.Zed .hpp all
      dev.zed.Zed .rs all
      dev.zed.Zed .go all
      dev.zed.Zed .java all
      dev.zed.Zed .swift all
      dev.zed.Zed .m all
      dev.zed.Zed .mm all
      dev.zed.Zed .php all
      dev.zed.Zed .lua all
      dev.zed.Zed .pl all
      dev.zed.Zed .env all
      dev.zed.Zed .gitignore all
      dev.zed.Zed .gitconfig all
      dev.zed.Zed .editorconfig all
      dev.zed.Zed .dockerfile all
      dev.zed.Zed .makefile all
      dev.zed.Zed .html all
      dev.zed.Zed .htm all
      dev.zed.Zed .css all
      dev.zed.Zed .scss all
      dev.zed.Zed .sass all
      dev.zed.Zed .less all
      # Use Gapplin for SVG files instead of text editor
      com.wolfrosch.Gapplin .svg all
      com.wolfrosch.Gapplin public.svg-image all
      dev.zed.Zed .xml all
      dev.zed.Zed .csv all
      dev.zed.Zed .sql all
      EOF

      # Apply the duti configuration as the primary user
      if command -v duti >/dev/null 2>&1; then
        sudo -u emiller duti /tmp/duti-config.txt
        echo "File associations configured successfully"
      else
        echo "Warning: duti not found, skipping file association configuration"
      fi

      # Clean up
      rm -f /tmp/duti-config.txt
    '';

    # Enable sudo authentication with Touch ID.
    security.pam.services.sudo_local.touchIdAuth = true;

    # Passwordless sudo for darwin-rebuild (enables agent-driven rebuilds)
    security.sudo.extraConfig = ''
      emiller ALL=(root) NOPASSWD: /run/current-system/sw/bin/darwin-rebuild *
    '';

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
