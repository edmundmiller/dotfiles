# modules/desktop/apps/raycast.nix
#
# Raycast launcher — replaces Spotlight
#
# Manages:
#   - Installation via nixpkgs (not homebrew)
#   - Disable Spotlight hotkey so Raycast can use ⌘Space
#   - Core preferences via defaults (vim nav, appearance, etc.)
#   - Script commands symlinked into ~/.config/raycast/scripts/
#   - Auto-launch via launchd
#
# NOT managed (Raycast stores these in encrypted SQLite):
#   - Extension installs/configs
#   - Extension hotkey bindings
#   - Cloud sync settings
#
# Why homebrew instead of nixpkgs:
#   - Raycast is Darwin-only, homebrew cask has auto_updates
#   - nixpkgs lags ~1 month behind (manual PRs by volunteers)
#   - homebrew: 1.104.5, nixpkgs: 1.104.3 (as of 2026-02)
{
  config,
  lib,
  isDarwin,
  ...
}:
with lib;
with lib.my;
let
  cfg = config.modules.desktop.apps.raycast;
  inherit (config.dotfiles) configDir;
in
{
  options.modules.desktop.apps.raycast = with types; {
    enable = mkBoolOpt false;
  };

  config = optionalAttrs isDarwin (
    mkIf cfg.enable {
      # Install via homebrew cask (auto_updates, always current)
      homebrew.casks = [ "raycast" ];

      # Disable Spotlight hotkey so Raycast can claim ⌘Space
      system.defaults.CustomUserPreferences = {
        "com.apple.symbolichotkeys" = {
          AppleSymbolicHotKeys = {
            "64" = {
              enabled = false;
              value = {
                type = "standard";
                parameters = [
                  32
                  49
                  1048576
                ];
              };
            };
          };
        };

        # Raycast preferences
        "com.raycast.macos" = {
          raycastGlobalHotkey = "Command-49"; # ⌘Space
          raycastShouldFollowSystemAppearance = true;
          navigationCommandStyleIdentifierKey = "vim";
          onboardingCompleted = true;
          useHyperKeyIcon = true;
          raycastPreferredWindowMode = "compact";
          "raycastUI_preferredTextSize" = "large";
        };
      };

      # Auto-launch Raycast at login
      launchd.user.agents.raycast = {
        command = ''"/Applications/Raycast.app/Contents/MacOS/Raycast"'';
        serviceConfig.RunAtLoad = true;
      };

      # Symlink script commands
      home-manager.users.${config.user.name} = {
        home.file = {
          # Raycast script commands
          "Scripts/raycast/neovide-quake-pro.swift" = {
            source = "${configDir}/raycast-scripts/neovide-quake-pro.swift";
            executable = true;
          };
          "Scripts/raycast/open-daily-note.sh" = {
            source = "${configDir}/raycast-scripts/open-daily-note.sh";
            executable = true;
          };
          "Scripts/raycast/neovide-simple-toggle.swift" = {
            source = "${config.dotfiles.binDir}/raycast-scripts/neovide-simple-toggle.swift";
            executable = true;
          };

          # Todo.txt raycast scripts
          "Scripts/raycast/todo/add-todotxt-task.sh" = {
            source = "${configDir}/todo/raycast/add-todotxt-task.sh";
            executable = true;
          };
          "Scripts/raycast/todo/do-todotxt-task.sh" = {
            source = "${configDir}/todo/raycast/do-todotxt-task.sh";
            executable = true;
          };
          "Scripts/raycast/todo/list-todotxt-projects.sh" = {
            source = "${configDir}/todo/raycast/list-todotxt-projects.sh";
            executable = true;
          };
          "Scripts/raycast/todo/list-todotxt-tasks.sh" = {
            source = "${configDir}/todo/raycast/list-todotxt-tasks.sh";
            executable = true;
          };
          "Scripts/raycast/todo/list-todotxt-tasks-context.sh" = {
            source = "${configDir}/todo/raycast/list-todotxt-tasks-context.sh";
            executable = true;
          };
          "Scripts/raycast/todo/_lib_todo_raycast.sh" = {
            source = "${configDir}/todo/raycast/_lib_todo_raycast.sh";
            executable = true;
          };
        };
      };
    }
  );
}
