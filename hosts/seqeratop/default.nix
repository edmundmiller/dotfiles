{
  config,
  lib,
  pkgs,
  ...
}:
{
  imports = [ ./agento11y.nix ];

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
        nextflow.enable = true;
        node.enable = true;
        node.useFnm = true;
        python.enable = true;
        python.conda.enable = true;
      };

      shell = {
        "1password".enable = true;
        amoxide.enable = true;
        agentBrowser.enable = true;
        druk.enable = true;
        skillkit.enable = true;
        direnv.enable = true;
        mise = {
          enable = true;
          # Frontier's min_version is ahead of nixpkgs' mise.
          homebrew = true;
        };
        git.enable = true;
        git.hunk.enable = true;
        jj.enable = true;
        tmux.enable = true;
        acpx.enable = true;
        cliamp.enable = true;
        tmux.jmux.enable = false;
        herdr.enable = true;
        rex.enable = true;
        tmux.jmux.configFile = "${config.dotfiles.configDir}/jmux/config.json";
        tmux.opensessions.enable = true;
        dmux.enable = false;
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
        mo.enable = true;
        # Scan roots for `mo purge` (build-artifact cleanup). This list
        # REPLACES mole's built-in defaults, so anything omitted here is
        # never scanned. Nonexistent dirs are a harmless no-op and are kept
        # so coverage kicks in automatically if they ever appear.
        #
        # Deliberate omissions:
        #   ~/Library/CloudStorage — mole scans this by default, but purging
        #     artifacts inside iCloud/Google Drive propagates deletions to
        #     other machines and can force-download dataless files.
        #   ~/Repos — same inode as ~/repos on case-insensitive APFS.
        mo.purgePaths = [
          # Actually in use on this host
          "~/src"
          "~/repos"
          "~/.codex/worktrees"
          "~/.local/share/herdr/worktrees"
          # Mole defaults, kept for future coverage
          "~/.claude/worktrees"
          "~/www"
          "~/dev"
          "~/Projects"
          "~/GitHub"
          "~/Code"
          "~/Workspace"
          "~/Development"
        ];
      };

      agents = {
        default = "pi";
        mcp = {
          enable = true;
          agents.amp = true;
          servers = {
            github.enable = true;
            seqera.enable = true;
            linear.enable = false;
            openaiDeveloperDocs.enable = true;
            plannotator-inbox.enable = true;
          };
        };
        pi = {
          enable = true;
          classifierModel = {
            provider = "openrouter";
            id = "~typesafe/jev-latest";
          };
          # Work host cycles only Sol 6.1 and Luna 6; shared defaults add Astra.
          enabledModels = [
            "openai-codex/gpt-6.1-sol"
            "openai-codex/gpt-6-luna"
          ];
          cursorSdk.enable = true;
          memoryRemote = "git@github.com:edmundmiller/pi-memory";
        };
        agentsview.enable = true;
        claude.enable = true;
        codex = {
          enable = true;
        };
        opencode.enable = true;
        hermes.enable = false; # Managed manually
      };

      services = {
        obsidian-sync.enable = false;
        containers = {
          enable = true;
          provider = "orbstack";
        };
        ssh.enable = true;
        mosh.enable = true;
      };

      desktop.macos.enable = true;

      desktop = {
        apps.audioPriorityBar.enable = true;
        apps.handy.enable = true;
        apps.tinybar.enable = true;
        apps.tldraw.enable = true;
        term = {
          ghostty = {
            enable = true;
            macosTerminalProfileName = "Seqera";
            # Stylix drives ghostty colors from the Seqera Dark base16 scheme
            # (see modules.theme.stylix below); the theme stack owns the matching
            # Herdr/Pi/Hunk adapters and links named Seqera Ghostty themes.
            configInit = ''
              font-family = JetBrains Mono
              font-size = 14
            '';
          };
          themeStack = {
            enable = true;
            variant = "seqera";
          };
        };
      };

      # Stylix: drive the whole theme from the Seqera brand palette so
      # ghostty, vim/bat/btop/etc. all match the existing SeqeraDark
      # configuration. Scheme yaml is mirrored from
      # config/ghostty/themes/SeqeraDark.
      theme.stylix = {
        enable = true;
        polarity = "dark";
        base16Scheme = "${config.dotfiles.configDir}/themes/seqera-dark.yaml";
        # Use the module's generated solid-color placeholder instead of a
        # machine-local Downloads path, so evaluation is reproducible.
        fallbackImageColor = "201637"; # Seqera deep purple (base00)
        fonts.monospace = {
          package = pkgs.jetbrains-mono;
          name = "JetBrains Mono";
        };
      };
    };

    # Override the primary user for this host
    system.primaryUser = "edmundmiller";

    # Touch ID for sudo. reattach moves panes started by the Rex or tmux server
    # into the GUI session, where pam_tid can reach the sensor. It needs the
    # lid open or the Magic Keyboard connected.
    security.pam.services.sudo_local = {
      touchIdAuth = true;
      reattach = true;
    };

    # Source checkouts contain hundreds of thousands of duplicated dependency
    # files. Keep them out of Spotlight's semantic index.
    system.activationScripts.spotlightExcludeSrc.text = ''
      SPOTLIGHT_PRIVACY_PLIST="/System/Volumes/Data/.Spotlight-V100/VolumeConfiguration.plist"
      SPOTLIGHT_EXCLUDED_PATH="${config.user.home}/src"

      if [ ! -f "$SPOTLIGHT_PRIVACY_PLIST" ]; then
        echo "warning: Spotlight privacy configuration is unavailable" >&2
      elif ! /usr/libexec/PlistBuddy -c "Print :Exclusions" "$SPOTLIGHT_PRIVACY_PLIST" 2>/dev/null \
        | /usr/bin/grep -Fq -- "$SPOTLIGHT_EXCLUDED_PATH"; then
        /usr/libexec/PlistBuddy -c "Add :Exclusions array" "$SPOTLIGHT_PRIVACY_PLIST" 2>/dev/null || true
        /usr/libexec/PlistBuddy -c "Add :Exclusions:0 string $SPOTLIGHT_EXCLUDED_PATH" "$SPOTLIGHT_PRIVACY_PLIST"
        /bin/launchctl kickstart -k system/com.apple.metadata.mds || \
          echo "warning: restart Spotlight to apply the src exclusion" >&2
      fi
    '';

    ## CPU
    # 11 cores; pairs with nix.settings.cores = 2
    # (modules/darwin-base.nix). nix-darwin's max-jobs = auto would
    # resolve to 11 here, and auto x all-cores lets 121 threads run.
    nix.settings.max-jobs = lib.mkDefault 6;

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
        extraEnv.HOMEBREW_BUNDLE_CASK_SKIP = "rooms"; # Unsupported postflight keywords in pinned Homebrew.
        extraFlags = [ "--quiet" ]; # Reduce Homebrew activation chatter
      };
    }
    // (import ./homebrew.nix);

    environment.systemPackages = with pkgs; [
      llm-agents.qmd
      my.betteraudio
      my.emeraldian
      my.excalidraw-cli
      my.zele
      my.quill
      my.work-calendar-busy
    ];

    home-manager.users.${config.user.name} =
      { lib, ... }:
      {
        # Seqera public key (op://Employee/Seqera Key) on disk. The matching
        # private key is ~/.ssh/id_ed25519 on this host.
        home.file.".ssh/seqera.pub".text =
          "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKLH5ywipRADaxVcZ/kK2Pg9kwRZyj/ABEurj+5KXHty Seqera Key\n";

        # Shared config-seqera pins signingkey to the literal pubkey, which
        # routes ssh-keygen through the 1Password SSH agent (-U) and blocks
        # headless agents on auth prompts. Sign with the on-disk key instead.
        xdg.configFile."git/config-seqera".source = lib.mkForce (
          pkgs.writeText "config-seqera" ''
            [user]
                email = edmund.miller@seqera.io
                signingkey = "~/.ssh/id_ed25519"
          ''
        );

        # sf CLI's bundled plugin-telemetry (3.7.2) spawns a detached
        # upload.js per invocation that finishes its upload but never exits:
        # the AppInsights reporter leaves un-unref'd libuv handles, so each
        # process parks in kevent forever holding ~84MB. 229 of them had
        # accumulated here and filled swap. Disabling telemetry stops the
        # spawns entirely.
        home.sessionVariables = {
          SF_DISABLE_TELEMETRY = "true";

          # Sol for coding, Terra for intent, Luna for done. Cursor stays on
          # Pi's cycling list as the fallback when Codex is down.
          PI_MODEL_SWITCH_INTENT = "openai-codex/gpt-6.1-sol";
          PI_MODEL_SWITCH_CODING = "openai-codex/gpt-6.1-sol";
          PI_MODEL_SWITCH_DONE = "openai-codex/gpt-6-luna";
        };

        home.file."Library/Application Support/com.elgato.StreamDeck/Plugins/dev.timvdhoorn.herdr-agents.sdPlugin".source =
          "${pkgs.my.stream-deck-herdr-plugin}/dev.timvdhoorn.herdr-agents.sdPlugin";

        home.activation.removeLegacyQmd = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
          rm -f "$HOME/.bun/bin/qmd" "$HOME/.cache/npm/bin/qmd"
        '';

        home.activation.removeLegacyBunClis = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
          legacy="$HOME/.bun/bin/excalidraw"
          if [ -L "$legacy" ]; then
            case "$(readlink "$legacy")" in
              ../install/global/node_modules/*|"$HOME"/.bun/install/global/node_modules/*)
                rm "$legacy"
                ;;
            esac
          fi
        '';
      };

  };
}
