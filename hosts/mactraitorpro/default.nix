{
  config,
  inputs,
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
        file-associations = {
          enable = true;
          editor = "zed";
        };
      };
      dev = {
        nixlang.enable = true;
        node.enable = true;
        node.useFnm = true;
        node.bunGlobalPackages = [
          "critique@0.1.139"
        ];
        # FIXME: Python disabled - bundled whisper currently includes Python 3.13
        # Conflicts with python module's withPackages env. See dotfiles-c11.
        python.enable = false;
        python.conda.enable = false;
      };

      shell = {
        "1password".enable = true;
        ai = {
          enable = true;
          mcporter.enable = true;
        };
        amoxide.enable = true;
        agentBrowser.enable = true;
        direnv.enable = true;
        mise.enable = true;
        git = {
          enable = true;
          gitbutler.enable = false;
          gitnexus.enable = true;
          hunk.enable = true;
          lazydiff.enable = true;
        };
        jj.enable = true;
        # Disable tmux on this host so Pi does not inject tmux-oriented
        # shell tools/extensions; Herdr remains the preferred pane/workspace layer.
        tmux.enable = false;
        tmux.workmux.enable = false;
        acpx.enable = true;
        herdr.enable = true;
        herdr.mainCodingAgent = "omp";
        herald.enable = true;
        tmux.jmux.enable = false;
        tmux.jmux.package = pkgs.my.jmux;
        tmux.jmux.configFile = "${config.dotfiles.configDir}/jmux/config.json";
        tmux.opensessions.enable = false;
        tmux.experimental.sessionDots.enable = false;
        tmux.experimental.agentStatus.enable = false;
        dmux.enable = false;
        zsh = {
          enable = true;
          envInit = ''
            # Homebrew 5.1.11 on macOS 27 requires Xcode 27, even when the
            # installed CLT is already 27-compatible. Keep interactive `brew`
            # commands usable until Homebrew/Xcode catches up by matching the
            # activation-time workaround below.
            export HOMEBREW_FAKE_MACOS=26.0
          '';
        };
      };

      agents = {
        pi = {
          enable = true;
          secretReferences = {
            OPENCODE_GO_API_KEY = "op://Agents/MTP OpenCode Go/credential";
          };
        };
        agentsview.enable = true;
        claude.enable = true;
        codex.enable = true;
        omp = {
          enable = true;
          # Personal laptop providers: xai-oauth, openrouter, opencode-go, openai-codex.
          # No Cursor SDK, no VibeProxy here — do not pin cursor/* or vibeproxy/*.
          # Roles: sol (codex) for default/slow; composer for smol; grok only as default fallback.
          smolModel = "xai-oauth/grok-composer-2.5-fast";
          modelRoles = {
            smol = "xai-oauth/grok-composer-2.5-fast";
            default = "openai-codex/gpt-5.6-sol:low";
            slow = "openai-codex/gpt-5.6-sol:high";
            # Shared plan defaults to vibeproxy; override to sol.
            plan = "openai-codex/gpt-5.6-sol:high";
          };
          modelProviderOrder = [
            "openai-codex"
            "xai-oauth"
            "openrouter"
            "opencode-go"
          ];
          retry.modelFallback = true;
          retry.fallbackChains = {
            default = [
              "xai-oauth/grok-4.5"
              "opencode-go/glm-5.2"
            ];
            plan = [
              "opencode-go/glm-5.2"
            ];
            slow = [
              "openai-codex/gpt-5.6-terra:high"
              "openai-codex/gpt-5.6-luna:high"
              "opencode-go/glm-5.2"
            ];
            smol = [
              "openai-codex/gpt-5.4-mini"
              "opencode-go/deepseek-v4-flash"
            ];
          };
          dailyIntrospection.enable = true;
          dailyIntrospection.commit.enable = true;
          skilloptSleep.enable = true;
          skilloptSleep.maxSessions = 5;
          skilloptSleep.maxTasks = 1;
          skilloptSleep.autoCommit.enable = true;
        };
        opencode.enable = true;
      };

      services = {
        obsidian-sync.enable = false;
        docker.enable = true;
        mosh.enable = true;
        moshi.enable = true;
        tailscale.enable = true;
        ssh.enable = true;
        kittylitter = {
          enable = true;
          enabledAgents = [
            "pi"
            "amp"
          ];
        };
      };

      desktop.macos.enable = true;

      desktop = {
        apps.raycast.enable = true;
        apps.audioPriorityBar.enable = true;
        apps.handy.enable = true;
        apps.neovide.enable = true;
        term = {
          ghostty.enable = true;
          themeStack = {
            enable = true;
            variant = "catppuccin";
          };
        };
      };

      # Stylix: Catppuccin Mocha is the dark side of the terminal theme stack.
      # No real wallpaper here yet — the module mints a solid-color placeholder
      # PNG (base00) so stylix is happy without committing a binary asset.
      theme.stylix = {
        enable = true;
        polarity = "auto";
        schemeName = "catppuccin-mocha";
        fallbackImageColor = "1e1e2e"; # catppuccin mocha base00
      };
    };

    # Configure nix-homebrew for proper privilege management
    nix-homebrew = {
      enable = true;
      user = "emiller";
      enableRosetta = false; # ARM-only Homebrew on this host; no Intel prefix management needed now.
      autoMigrate = true; # Migrate existing homebrew installation
      mutableTaps = true; # Allow mutable taps for flexibility
      enableZshIntegration = false; # We handle brew in .zshenv with caching
    };

    # Mirror LookAway's meeting detection to the USB busylight. LookAway's built-in
    # automations only cover break start/end, so this tails its debug log for
    # meeting start/end transitions and calls bin/busylight-status.py.
    launchd.user.agents.lookaway-busylight =
      let
        busylightPython = pkgs.python3.withPackages (ps: [ ps.busylight-for-humans ]);
      in
      {
        command = "${busylightPython}/bin/python ${config.dotfiles.binDir}/lookaway-busylight-monitor.py";
        serviceConfig = {
          RunAtLoad = true;
          KeepAlive = true;
          StandardOutPath = "/tmp/lookaway-busylight.log";
          StandardErrorPath = "/tmp/lookaway-busylight.err";
          EnvironmentVariables = {
            BUSYLIGHT_STATUS_SCRIPT = "${config.dotfiles.binDir}/busylight-status.py";
            BUSYLIGHT_PYTHON = "${busylightPython}/bin/python";
          };
        };
      };

    # Manage native macOS Login Items declaratively. Keep Raycast Beta here and
    # do not also start it with a launchd.user.agent, or macOS will run two instances.
    environment.loginItems = {
      enable = true;
      items = [
        "/Applications/Raycast Beta.app"
        "/Applications/1Password.app"
        "/Applications/CleanShot X.app"
        "/Applications/LookAway.app"
        "/Applications/Monologue.app"
      ];
    };

    # Use homebrew to install casks and Mac App Store apps
    homebrew = {
      enable = true;

      # Homebrew configuration
      onActivation = {
        autoUpdate = false; # Don't auto-update during activation
        cleanup = "none"; # Don't remove anything for now
        upgrade = false; # Don't upgrade formulae during activation
        extraEnv = {
          # Homebrew 5.1.11 does not know macOS 27 yet; OS::Mac.version.to_sym
          # becomes :dunno and brew bundle crashes while resolving dependencies.
          # Pretend to be the newest Homebrew-supported macOS until brew adds 27.
          HOMEBREW_FAKE_MACOS = "26.0";

          # Xcode is huge, MAS-backed, and currently prompts/hangs under
          # nix-darwin activation. Keep it declared in masApps for inventory,
          # but do not let routine rebuilds install it interactively.
          HOMEBREW_BUNDLE_MAS_SKIP = "Xcode";
        };
        extraFlags = [ "--quiet" ]; # Reduce Homebrew activation chatter
      };
    }
    // import ./homebrew.nix;

    # Override the primary user for this host
    system.primaryUser = "emiller";

    # Add desktop helpers + qmd CLI
    environment.systemPackages = with pkgs; [
      inputs.clin.packages.${pkgs.stdenv.hostPlatform.system}.default
      llm-agents.qmd
      my.zele
      my.work-calendar-busy
      my.worktree-manager
    ];

    home-manager.users.${config.user.name} =
      { lib, ... }:
      {
        home.sessionVariables = {
          PI_MODEL_SWITCH_INTENT = "opencode-go/kimi-2.5";
          PI_MODEL_SWITCH_CODING = "openai-codex/gpt-5.3-codex";
          PI_MODEL_SWITCH_DONE = "opencode-go/kimi-2.5";
        };

        home.activation.removeLegacyQmd = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
          rm -f "$HOME/.bun/bin/qmd" "$HOME/.cache/npm/bin/qmd"
        '';

        home.activation.removeLegacyZele = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
          rm -f "$HOME/.bun/bin/zele" "$HOME/.cache/npm/bin/zele"
        '';

        home.file."Library/Application Support/com.elgato.StreamDeck/Plugins/dev.timvdhoorn.herdr-agents.sdPlugin".source =
          "${pkgs.my.stream-deck-herdr-plugin}/dev.timvdhoorn.herdr-agents.sdPlugin";

        # Keep the Seqera work wallpaper in a stable location and apply it to the desktop.
        # macOS wallpaper automation reliably accepts the PNG export; the SVG sibling
        # does not consistently stick as a desktop picture when scripted.
        # After setting the image, force Sonoma/Sequoia wallpaper placement to Centered
        # so the icon stays small and doesn't stretch.
        home.activation.setSeqeraWallpaper = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
          wallpaper_src="$HOME/Downloads/seqera 6/seqera_no_margin/pngs/Seqera Icon Light Green.png"
          wallpaper_dst="$HOME/Pictures/Wallpapers/Seqera Icon Light Green.png"
          wallpaper_store="$HOME/Library/Application Support/com.apple.wallpaper/Store/Index.plist"

          mkdir -p "$(dirname "$wallpaper_dst")"
          if [ -f "$wallpaper_src" ]; then
            cp -f "$wallpaper_src" "$wallpaper_dst"
          fi

          if [ -f "$wallpaper_dst" ] && [ -x /usr/bin/osascript ]; then
            wallpaper_escaped=$(printf '%s' "$wallpaper_dst" | sed 's/\\/\\\\/g; s/"/\\"/g')
            /usr/bin/osascript -e "tell application \"Finder\" to set desktop picture to POSIX file \"$wallpaper_escaped\"" >/dev/null 2>&1 || true
          fi

          if [ -f "$wallpaper_store" ]; then
            "${pkgs.python3}/bin/python3" \
              "${config.dotfiles.binDir}/macos-wallpaper-placement.py" \
              "$wallpaper_store" \
              Centered \
              201637
            killall WallpaperAgent >/dev/null 2>&1 || true
          fi
        '';
      };

    # TODO(dotfiles-lbea): Remove this shim cleanup block after a few rebuild cycles once
    # we're confident no machines/users still carry legacy /usr/local/bin/brew links.
    # Cleanup legacy Intel brew shim if it still exists from older Rosetta-enabled setups.
    system.activationScripts.cleanupLegacyIntelBrew.text = ''
      if [ -L "/usr/local/bin/brew" ]; then
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
