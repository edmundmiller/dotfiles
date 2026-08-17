{
  config,
  inputs,
  pkgs,
  ...
}:
let
  obsidianVault = "${config.user.home}/obsidian-vault";
  clin = inputs.clin.packages.${pkgs.stdenv.hostPlatform.system}.default;
  clinWithVaultEnv = pkgs.writeShellScriptBin "clin" ''
    for arg in "$@"; do
      case "$arg" in
        --vault | --vault=*)
          exec ${clin}/bin/clin "$@"
          ;;
      esac
    done

    if [ -n "''${CLIN_VAULT:-}" ]; then
      exec ${clin}/bin/clin --vault "$CLIN_VAULT" "$@"
    fi

    exec ${clin}/bin/clin "$@"
  '';
  obsidianGuardDir = "${config.user.home}/Library/Application Support/obsidian-sync-guard";
  obsidianVaultGitDirtCheck = pkgs.my.obsidian-vault-git-dirt-check;
  obsidianVaultGitDirtAudit = pkgs.writeShellScript "obsidian-vault-git-dirt-audit" ''
    set -u
    mkdir -p ${builtins.toJSON obsidianGuardDir}
    output="$(${obsidianVaultGitDirtCheck}/bin/obsidian-vault-git-dirt-check ${builtins.toJSON obsidianVault} 2>&1)"
    rc=$?
    if [ "$rc" -eq 0 ]; then
      exit 0
    fi
    printf '%s %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$output" >> ${builtins.toJSON "${obsidianGuardDir}/git-dirt.log"}
    /usr/bin/osascript -e 'display notification "Unexpected changes outside 00_Inbox; inspect the Git dirt log." with title "Obsidian vault Git audit"' >/dev/null 2>&1 || true
    exit "$rc"
  '';
  openwikiDailyThreadAudit = pkgs.writeShellScript "openwiki-daily-thread-audit" ''
    set -eu
    codex_executable="''${CODEX_EXECUTABLE:-${pkgs.llm-agents.codex}/bin/codex}"
    exec "$codex_executable" exec resume \
      019ff3ad-6ad9-75d0-8c9d-62008a15d79e \
      "Continue the existing OpenWiki recovery monitoring in this thread. Perform a strictly read-only audit of the Mac OpenWiki scheduled ingestion pipeline. Inspect the loaded 02:00 LaunchAgent, latest ingestion logs and connector states, isolated checkout status, and authoritative remote-main equality. Report the latest run's exact timestamp, job ID, failedSourceCount, and source outcomes. If healthy, say so plainly. Do not edit, commit, push, kickstart, or repair anything. If unhealthy, diagnose the cause and give the smallest next action."
  '';
  obsidianDesktopGuard = pkgs.writeShellScript "obsidian-desktop-sync-guard" ''
    set -u
    mkdir -p ${builtins.toJSON obsidianGuardDir}
    output="$(${pkgs.bun}/bin/bun ${builtins.toJSON "${obsidianVault}/scripts/obsidian-sync-safety-check.ts"} \
      --vault ${builtins.toJSON obsidianVault} \
      --policy ${builtins.toJSON "${obsidianVault}/07_Metadata/Validation/obsidian-sync-policy.json"} \
      --engine desktop \
      --config ${builtins.toJSON "${obsidianVault}/.obsidian/sync.json"} \
      --state ${builtins.toJSON "${obsidianGuardDir}/state.json"} \
      --json 2>&1)"
    rc=$?
    if [ "$rc" -eq 0 ]; then
      exit 0
    fi
    printf '%s %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$output" >> ${builtins.toJSON "${obsidianGuardDir}/incident.log"}
    reason="$(printf '%s' "$output" | ${pkgs.jq}/bin/jq -r '.violations[0].message // empty' 2>/dev/null || true)"
    if [ -z "$reason" ]; then
      reason="Safety check failed; inspect the incident log."
    fi
    notification="$reason Fix the issue, then reopen Obsidian."
    /usr/bin/osascript -e 'tell application "Obsidian" to quit' >/dev/null 2>&1 || true
    /usr/bin/osascript \
      -e 'on run argv' \
      -e 'display notification (item 1 of argv) with title "Obsidian closed to protect your vault" subtitle "Desktop Sync paused by safety guard"' \
      -e 'end run' \
      "$notification" >/dev/null 2>&1 || true
    exit "$rc"
  '';
in
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
          "vercel@58.9.0"
        ];
        # FIXME: Python disabled - bundled whisper currently includes Python 3.13
        # Conflicts with python module's withPackages env. See dotfiles-c11.
        python.enable = false;
        python.conda.enable = false;
      };

      shell = {
        "1password".enable = true;
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
        herdr.vercelSandbox.enable = true;
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
        mo.enable = true;
        # TODO: mirror the seqeratop purgePaths audit (13976f8c8e38). This list
        # REPLACES mole's built-in defaults, so the agent worktree roots and the
        # standard project dirs are currently never scanned. Verify which paths
        # exist on THIS host before copying — the seqeratop list was pruned for
        # its own layout, and ~/Library/CloudStorage should stay omitted since
        # purging artifacts there propagates deletions across machines.
        mo.purgePaths = [
          "~/src"
          "~/repos"
        ];
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
        hermes-local = {
          enable = true;
          profiles = [
            "amosburton"
            "orchestrator"
          ];
        };
        omp = {
          enable = true;
          # Personal laptop providers: xai-oauth, openrouter, opencode-go, openai-codex, google-antigravity.
          # No Cursor SDK, no VibeProxy here — do not pin cursor/* or vibeproxy/*.
          # Roles: Sol default/smol/advisor/slow/plan; Luna xhigh task; K3 designer; Luna commit/tiny; Gemini vision.
          smolModel = "openai-codex/gpt-5.6-sol:low";
          modelRoles = {
            vision = "google-antigravity/gemini-3.5-flash";
            default = "openai-codex/gpt-5.6-sol:medium";
            designer = "opencode-go/kimi-k3:high";
            advisor = "openai-codex/gpt-5.6-sol:high";
            slow = "openai-codex/gpt-5.6-sol:xhigh";
            # Shared plan defaults to vibeproxy; override to sol.
            plan = "openai-codex/gpt-5.6-sol:high";
            task = "openai-codex/gpt-5.6-luna:xhigh";
            commit = "openai-codex/gpt-5.6-luna:low";
            tiny = "openai-codex/gpt-5.6-luna:low";
          };
          modelProviderOrder = [
            "openai-codex"
            "xai-oauth"
            "opencode-go"
            "openrouter"
          ];
          retry.modelFallback = true;
          retry.fallbackChains = {
            default = [
              "openai-codex/gpt-5.6-luna:medium"
              "xai-oauth/grok-4.6"
              "opencode-go/kimi-k3:high"
              "openrouter/moonshotai/kimi-k3:high"
            ];
            plan = [
              "openai-codex/gpt-5.6-luna:high"
              "opencode-go/kimi-k3:high"
              "openrouter/moonshotai/kimi-k3:high"
            ];
            advisor = [
              "openai-codex/gpt-5.6-luna:high"
              "xai-oauth/grok-4.6"
              "opencode-go/kimi-k3:high"
            ];
            task = [
              "openai-codex/gpt-5.6-sol:xhigh"
              "xai-oauth/grok-4.6"
              "opencode-go/deepseek-v4-flash"
            ];
            commit = [
              "openai-codex/gpt-5.6-sol:low"
              "xai-oauth/grok-4.6"
            ];
            slow = [
              "openai-codex/gpt-5.6-terra:high"
              "openai-codex/gpt-5.6-luna:high"
              "xai-oauth/grok-4.6"
              "opencode-go/kimi-k3:high"
              "openrouter/moonshotai/kimi-k3:high"
            ];
            smol = [
              "openai-codex/gpt-5.6-luna"
              "openai-codex/gpt-5.6-sol:low"
              "opencode-go/deepseek-v4-flash"
            ];
            tiny = [
              "openai-codex/gpt-5.6-sol:low"
              "xai-oauth/grok-4.6"
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
        appleContainer.enable = true;
        obsidian-sync.enable = false;
        docker.enable = false;
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
          ghostty.keybindingsInit = ''
            # Herdr's Ctrl-Space prefix is encoded as NUL in the terminal.
            keybind = super+h=text:\x00h
            keybind = super+j=text:\x00j
            keybind = super+k=text:\x00k
            keybind = super+l=text:\x00l
          '';
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

    launchd.user.agents.obsidian-sync-guard = {
      command = "${obsidianDesktopGuard}";
      serviceConfig = {
        RunAtLoad = true;
        StartInterval = 30;
        StandardOutPath = "/tmp/obsidian-sync-guard.log";
        StandardErrorPath = "/tmp/obsidian-sync-guard.err";
      };
    };

    launchd.user.agents.obsidian-vault-git-dirt-check = {
      command = "${obsidianVaultGitDirtAudit}";
      serviceConfig = {
        StartCalendarInterval = [
          {
            Hour = 9;
            Minute = 0;
          }
          {
            Hour = 21;
            Minute = 0;
          }
        ];
        StandardOutPath = "/tmp/obsidian-vault-git-dirt-check.log";
        StandardErrorPath = "/tmp/obsidian-vault-git-dirt-check.err";
      };
    };

    launchd.user.agents.openwiki-daily-thread-audit = {
      command = "${openwikiDailyThreadAudit}";
      serviceConfig = {
        StartCalendarInterval = {
          Hour = 3;
          Minute = 0;
        };
        WorkingDirectory = obsidianVault;
        StandardOutPath = "${config.user.home}/.openwiki/logs/daily-thread-audit.log";
        StandardErrorPath = "${config.user.home}/.openwiki/logs/daily-thread-audit.log";
        EnvironmentVariables = {
          HOME = config.user.home;
          PATH = "/etc/profiles/per-user/${config.user.name}/bin:/run/current-system/sw/bin:/usr/bin:/bin:/usr/sbin:/sbin";
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

          # MAS installs are unreliable during headless activation. Keep the apps
          # declared for inventory, but do not install them during routine rebuilds.
          HOMEBREW_BUNDLE_MAS_SKIP = "Xcode Keynote Numbers";
        };
        extraFlags = [ "--quiet" ]; # Reduce Homebrew activation chatter
      };
    }
    // import ./homebrew.nix;

    # Override the primary user for this host
    system.primaryUser = "emiller";

    # Add desktop helpers + qmd CLI
    environment.systemPackages = with pkgs; [
      clinWithVaultEnv
      llm-agents.qmd
      my.hex
      my.meat
      my.openwiki
      my.writer
      my.zele
      my.work-calendar-busy
    ];

    home-manager.users.${config.user.name} =
      { lib, ... }:
      {
        home.sessionVariables = {
          PI_MODEL_SWITCH_INTENT = "opencode-go/kimi-2.5";
          PI_MODEL_SWITCH_CODING = "openai-codex/gpt-5.6-sol";
          PI_MODEL_SWITCH_DONE = "opencode-go/kimi-2.5";
        };

        home.activation.removeLegacyQmd = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
          rm -f "$HOME/.bun/bin/qmd" "$HOME/.cache/npm/bin/qmd"
        '';

        home.activation.removeLegacyZele = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
          rm -f "$HOME/.bun/bin/zele" "$HOME/.cache/npm/bin/zele"
        '';

        home.activation.removeLegacyOpenWiki = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
          rm -f "$HOME/.cache/npm/bin/openwiki"
        '';

        home.file."Library/Application Support/com.elgato.StreamDeck/Plugins/dev.timvdhoorn.herdr-agents.sdPlugin".source =
          "${pkgs.my.stream-deck-herdr-plugin}/dev.timvdhoorn.herdr-agents.sdPlugin";
        home.file."Library/Application Support/com.clin.clin/config.toml".source =
          "${config.dotfiles.configDir}/clin/config.toml";

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
