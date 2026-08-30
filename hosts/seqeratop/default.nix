{
  config,
  lib,
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
        cliamp.enable = true;
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
          # Seqera Enterprise OpenAI is back. Default follows shared
          # settings.jsonc (openai-codex gpt-5.6-sol). Sol/Terra/Luna stay on
          # the cycling list; Cursor Grok is the cross-provider fallback.
          # Composer and Kimi K3 stay off this host's automatic lists.
          # No opencode-go on this host.
          enabledModels = [
            "openai-codex/gpt-5.6-sol"
            "openai-codex/gpt-5.6-terra"
            "openai-codex/gpt-5.6-luna"
            "cursor/cursor-grok-4.6-medium"
            "cursor/cursor-grok-4.6-high"
            "cursor/cursor-grok-4.6-xhigh"
            "cursor/cursor-grok-4.6-low-fast"
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
          # Work laptop providers: vibeproxy (Claude subscription), openai-codex
          # (Seqera Enterprise), cursor, google-antigravity.
          #
          # Three tiers, in this order: vibeproxy Claude primaries -> openai-codex
          # GPT-5.6 -> cursor Grok 4.6 as the last-resort net. The Claude
          # subscription is flat-rate, so burn it first; Codex is the metered
          # second tier; Cursor only runs when both are down.
          #
          # Opus 5 at varying thinking levels drives the interactive roles.
          # default and smol are deliberately the same Opus id so the first-edit
          # prewalk handoff is a same-model level change rather than a
          # cross-provider hop that resets the transcript and the prompt cache
          # (modules/agents/omp/docs/model-roles.md).
          #
          # Three roles step off Opus on purpose: delegated `task` work runs on
          # Sonnet 5 at xhigh, `commit` on Haiku, and `tiny` skips the Claude
          # tier entirely for Codex Luna -- it is titles, memory, and difficulty
          # classification, so the sub buys nothing there. Haiku carries no
          # `:level` suffix because config/omp/models.yml declares
          # `reasoning: true` for opus-5/sonnet-5/fable-5 but not for it.
          #
          # VibeProxy has no model auto-discovery: every id used here must also
          # appear in config/omp/models.yml. It exposes Claude only -- do not
          # invent xai-oauth or openai ids under the vibeproxy/ prefix.
          # `omp models vibeproxy` reports minimal/low/medium/high/xhigh, so
          # there is no `:max` level on this provider.
          #
          # Cursor catalog from `omp models cursor` on this host: grok-4.6
          # medium/high/xhigh/low-fast and gemini-3.5-flash. Grok reports
          # thinking `-`, so those ids carry no `:level` suffix. Composer
          # and Kimi K3 remain in the Cursor catalog but are not automatic
          # fallbacks or Pi cycle entries.
          #
          # Vision stays on Gemini via google-antigravity -- a deliberate
          # specialist pick, not part of the three-tier ordering. Its fallbacks
          # need images=yes, which rules out every cursor-grok id, so the Cursor
          # hop is cursor/gemini-3.5-flash.
          #
          # Pi has no vibeproxy wiring, so pi.enabledModels and PI_MODEL_SWITCH_*
          # stay openai-codex -> cursor. Pi and omp intentionally disagree on
          # which provider is primary.
          #
          # smolModel and modelRoles.smol are both pinned to the same id on
          # purpose. PI_SMOL_MODEL wins at runtime, but the shared
          # config/omp/config.yml sets modelRoles.smol to an xai-oauth id and
          # that provider does not exist on this host -- without the overlay a
          # dead selector leaks into the rendered config.yml.
          smolModel = "vibeproxy/claude-opus-5:low";
          modelRoles = {
            vision = "google-antigravity/gemini-3.5-flash";
            default = "vibeproxy/claude-opus-5:medium";
            smol = "vibeproxy/claude-opus-5:low";
            designer = "vibeproxy/claude-opus-5:high";
            advisor = "vibeproxy/claude-opus-5:high";
            slow = "vibeproxy/claude-opus-5:xhigh";
            plan = "vibeproxy/claude-opus-5:high";
            task = "vibeproxy/claude-sonnet-5:xhigh";
            commit = "vibeproxy/claude-haiku-4-5-20251001";
            tiny = "openai-codex/gpt-5.6-luna:low";
          };
          modelProviderOrder = [
            "vibeproxy"
            "openai-codex"
            "cursor"
            "google-antigravity"
          ];
          retry.modelFallback = true;
          retry.fallbackChains = {
            default = [
              "openai-codex/gpt-5.6-sol:medium"
              "openai-codex/gpt-5.6-luna:medium"
              "cursor/cursor-grok-4.6-medium"
            ];
            plan = [
              "openai-codex/gpt-5.6-sol:high"
              "openai-codex/gpt-5.6-luna:high"
              "cursor/cursor-grok-4.6-high"
            ];
            advisor = [
              "openai-codex/gpt-5.6-sol:high"
              "openai-codex/gpt-5.6-luna:high"
              "cursor/cursor-grok-4.6-high"
            ];
            designer = [
              "openai-codex/gpt-5.6-sol:high"
              "openai-codex/gpt-5.6-luna:high"
              "cursor/cursor-grok-4.6-high"
            ];
            task = [
              "openai-codex/gpt-5.6-luna:xhigh"
              "cursor/cursor-grok-4.6-xhigh"
            ];
            slow = [
              "openai-codex/gpt-5.6-sol:xhigh"
              "openai-codex/gpt-5.6-terra:high"
              "openai-codex/gpt-5.6-luna:high"
              "cursor/cursor-grok-4.6-xhigh"
            ];
            smol = [
              "openai-codex/gpt-5.6-sol:low"
              "openai-codex/gpt-5.6-luna:low"
              "cursor/cursor-grok-4.6-low-fast"
            ];
            commit = [
              "openai-codex/gpt-5.6-luna:low"
              "cursor/cursor-grok-4.6-low-fast"
            ];
            tiny = [
              "openai-codex/gpt-5.6-sol:low"
              "cursor/cursor-grok-4.6-low-fast"
            ];
            vision = [
              "vibeproxy/claude-opus-5:medium"
              "openai-codex/gpt-5.6-sol:medium"
              "cursor/gemini-3.5-flash"
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
        containers = {
          enable = true;
          provider = "orbstack";
        };
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

        # Keep one cross-family reviewer active on every turn. The roster entry
        # omits `model`, so it resolves through modelRoles.advisor (Opus 5) and
        # retry.fallbackChains.advisor owns the hops: Codex Sol/Luna, then
        # Cursor Grok only when both are down.
        home.file.".omp/agent/WATCHDOG.yml".text = ''
          advisors:
            - name: Opus
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

          # Sol for coding, Terra for intent, Luna for done. Cursor stays on
          # Pi's cycling list as the fallback when Codex is down.
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
