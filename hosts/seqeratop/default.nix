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
        zed.enable = true;
        file-associations = {
          enable = true;
          editor = "zed";
        };
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
        amoxide.enable = true;
        skillkit.enable = true;
        direnv.enable = true;
        mise.enable = true;
        git.enable = true;
        git.hunk.enable = true;
        jj.enable = true;
        tmux.enable = true;
        acpx.enable = true;
        tmux.jmux.enable = false;
        herdr.enable = true;
        # Seqera ghostty theme uses a dark purple background (#201637); use
        # the matching Pi theme palette so dim/muted text stays legible, and
        # apply the Seqera-branded Herdr UI theme on top of the terminal
        # palette.
        herdr.piThemeVariant = "seqera";
        herdr.themeVariant = "seqera";
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
      };

      agents = {
        pi = {
          enable = true;
          enabledModels = [
            "gpt-5.5"
            "cursor/composer-2.5"
            "gpt-5.4-mini"
          ];
          cursorSdk.enable = true;
          secretReferences = {
            OPENCODE_GO_API_KEY = "op://Agents/MTP OpenCode Go/credential";
          };
          memoryRemote = "git@github.com:edmundmiller/pi-memory";
        };
        agentsview.enable = true;
        claude.enable = true;
        codex.enable = true;
        omp = {
          enable = true;
          # Model roles for this box. seqeratop is logged into cursor +
          # openai-codex (verified in ~/.omp/agent/agent.db) and runs the
          # keyless VibeProxy app on :8317 (vibeproxy.enable below). smol uses
          # the PI_SMOL_MODEL env lever (wins over config.yml); the rest are
          # overlaid onto the shared config.yml at build time, leaving
          # mactraitorpro on the shared defaults.
          smolModel = "cursor/composer-2.5"; # Cursor Composer 2.5, fast/cheap
          modelRoles = {
            default = "openai-codex/gpt-5.5:medium"; # GPT-5.5 everyday driver
            # Opus 4.8 for planning via VibeProxy — same model as
            # cursor/claude-opus-4-8-high but on the flat-rate Claude sub, not
            # metered Cursor API. Runs free on the sub while the :8317 app is up;
            # falls back to metered Cursor Opus if it's down (see below).
            plan = "vibeproxy/claude-opus-4-8:high";
            advisor = "openai-codex/gpt-5.5:high"; # watchdog reviewer (reliable)
          };
          # plan runs on VibeProxy (needs the :8317 app up). Give that one role
          # a fallback to the same Opus 4.8 on metered Cursor, so planning keeps
          # working when the app is down instead of hard-failing. This flips
          # retry.modelFallback on for this host only; no other role gets a
          # chain, so they stay pinned per the shared config's no-fallback rule.
          modelFallbackChains = {
            plan = [ "cursor/claude-opus-4-8-high" ];
          };
          # Match the rest of this host's Seqera branding (stylix seqera-dark,
          # ghostty SeqeraDark/Light, herdr seqera variant). mactraitorpro
          # keeps the shared Catppuccin default.
          themeDark = "dark-seqera";
          themeLight = "light-seqera";
          # Wire omp to the VibeProxy menu-bar app (installed via the vibeproxy
          # homebrew cask). Exposes Claude/GPT subscription models on :8317 as
          # vibeproxy/* selectors; see config/omp/models.yml.
          vibeproxy.enable = true;
        };
        opencode.enable = true;
        hermes.enable = false; # Managed manually
      };

      services = {
        obsidian-sync.enable = false;
        docker.enable = true;
        ssh.enable = true;
      };

      desktop.macos.enable = true;

      desktop = {
        apps.audioPriorityBar.enable = true;
        apps.handy.enable = true;
        term.ghostty = {
          enable = true;
          macosTerminalProfileName = "Seqera";
          # Stylix drives ghostty colors from the Seqera Dark base16 scheme
          # (see modules.theme.stylix below); we no longer set `theme =`
          # here, otherwise ghostty would race with the stylix-generated
          # palette. Host-local font override stays put.
          configInit = ''
            font-family = JetBrains Mono
            font-size = 14
          '';
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
      my.zele
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

        home.sessionVariables = {
          PI_MODEL_SWITCH_INTENT = "openai-codex/gpt-5.4";
          PI_MODEL_SWITCH_CODING = "openai-codex/gpt-5.3-codex";
          PI_MODEL_SWITCH_DONE = "openai-codex/gpt-5.4";
        };

        # Host-local Ghostty themes in Seqera brand colors.
        xdg.configFile."ghostty/themes/SeqeraDark".source =
          "${config.dotfiles.configDir}/ghostty/themes/SeqeraDark";
        xdg.configFile."ghostty/themes/SeqeraLight".source =
          "${config.dotfiles.configDir}/ghostty/themes/SeqeraLight";

        home.file."Library/Application Support/com.elgato.StreamDeck/Plugins/dev.timvdhoorn.herdr-agents.sdPlugin".source =
          "${pkgs.my.stream-deck-herdr-plugin}/dev.timvdhoorn.herdr-agents.sdPlugin";

        home.activation.removeLegacyQmd = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
          rm -f "$HOME/.bun/bin/qmd" "$HOME/.cache/npm/bin/qmd"
        '';
      };

  };
}
