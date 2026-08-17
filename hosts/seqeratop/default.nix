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
        herdr.mainCodingAgent = "omp";
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
        pi = {
          enable = true;
          enabledModels = [
            "gpt-5.6-sol"
            "gpt-5.6-terra"
            "gpt-5.6-luna"
            "cursor/composer-2.5"
          ];
          cursorSdk.enable = true;
          secretReferences = {
            OPENCODE_GO_API_KEY = "op://Agents/MTP OpenCode Go/credential";
          };
          memoryRemote = "git@github.com:edmundmiller/pi-memory";
        };
        agentsview.enable = true;
        claude.enable = true;
        codex = {
          enable = true;
          seqeraMcp.enable = true;
        };
        omp = {
          enable = true;
          # Work laptop providers: cursor, openai-codex, vibeproxy (Claude/Anthropic),
          # Sonnet is the task/coding handoff; Haiku stays on commit/tiny
          # metadata work.
          # Fable drives slow/plan/designer with Codex Sol as first fallback.
          # Opus medium is the default; Opus low is smol.
          # Opus remains the primary default. Vision goes to Gemini via the
          # google-antigravity login (run `/login google-antigravity` in omp once).
          # Cursor Grok and Composer fast variants are fallbacks. VibeProxy
          # exposes Claude only; do not invent xai-oauth ids.
          # modelRoles only — avoid smolModel/PI_SMOL_MODEL, which overrides
          # rendered smol and can confuse commit/tiny vs prewalk handoff.
          modelRoles = {
            default = "vibeproxy/claude-opus-5:medium";
            smol = "vibeproxy/claude-opus-5:low";
            slow = "vibeproxy/claude-fable-5:high";
            plan = "vibeproxy/claude-fable-5:high";
            vision = "google-antigravity/gemini-3.5-flash";
            designer = "vibeproxy/claude-fable-5:medium";
            commit = "vibeproxy/claude-haiku-4-5-20251001";
            tiny = "vibeproxy/claude-haiku-4-5-20251001";
            task = "vibeproxy/claude-sonnet-5:low";
            advisor = "openai-codex/gpt-5.6-sol:high";
          };
          retry.fallbackChains = {
            advisor = [
              "vibeproxy/claude-opus-4-8:high"
            ];
            default = [
              "openai-codex/gpt-5.6-sol:medium"
              "cursor/cursor-grok-4.5-low-fast"
              "cursor/composer-2.5-fast"
            ];
            smol = [
              "openai-codex/gpt-5.6-sol:low"
              "cursor/cursor-grok-4.5-low-fast"
              "cursor/composer-2.5-fast"
            ];
            slow = [
              "openai-codex/gpt-5.6-sol:high"
            ];
            plan = [
              "openai-codex/gpt-5.6-sol:high"
            ];
            task = [
              "openai-codex/gpt-5.6-terra:low"
              "cursor/cursor-grok-4.5-low-fast"
              "cursor/composer-2.5-fast"
            ];
            vision = [
              "openai-codex/gpt-5.6-sol:medium"
              "openai-codex/gpt-5.6-luna:medium"
            ];
            designer = [
              "openai-codex/gpt-5.6-sol:medium"
            ];
            commit = [
              "openai-codex/gpt-5.6-luna:low"
              "cursor/composer-2.5-fast"
            ];
            tiny = [
              "cursor/composer-2.5-fast"
              "openai-codex/gpt-5.6-luna:low"
            ];
          };
          # Match the rest of this host's Seqera branding (stylix seqera-dark,
          # ghostty SeqeraDark/Light, herdr seqera variant). mactraitorpro
          # keeps the shared Catppuccin default.
          themeDark = "dark-seqera";
          themeLight = "light-seqera";
          mcpServers.seqera = {
            type = "http";
            url = "https://mcp.seqera.io/mcp";
          };
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
        mosh.enable = true;
        moshi.enable = true;
      };

      desktop.macos.enable = true;

      desktop = {
        apps.audioPriorityBar.enable = true;
        apps.handy.enable = true;
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

        # Keep one cross-family reviewer active on every turn. Advisor runtimes
        # use retry.fallbackChains, so Opus runs only when Sol fails.
        home.file.".omp/agent/WATCHDOG.yml".text = ''
          advisors:
            - name: Sol
        '';

        # Seqeratop-only: `hey re` needs a TTY for sudo, so it must run in the
        # current Herdr session rather than a piped bash call.
        home.file.".omp/agent/rules/hey-rebuilds.md".source =
          "${config.dotfiles.configDir}/omp/rules/hey-rebuilds.md";

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

          PI_MODEL_SWITCH_INTENT = "openai-codex/gpt-5.6-terra";
          PI_MODEL_SWITCH_CODING = "openai-codex/gpt-5.6-sol";
          PI_MODEL_SWITCH_DONE = "openai-codex/gpt-5.6-luna";
        };

        home.file."Library/Application Support/com.elgato.StreamDeck/Plugins/dev.timvdhoorn.herdr-agents.sdPlugin".source =
          "${pkgs.my.stream-deck-herdr-plugin}/dev.timvdhoorn.herdr-agents.sdPlugin";

        home.activation.removeLegacyQmd = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
          rm -f "$HOME/.bun/bin/qmd" "$HOME/.cache/npm/bin/qmd"
        '';
      };

  };
}
