# modules/desktop/apps/raycast.nix
#
# Raycast launcher — replaces Spotlight
#
# Manages:
#   - Disable Spotlight hotkey so Raycast can use ⌘Space
#   - Core preferences via defaults (vim nav, appearance, etc.)
#   - Script commands symlinked into ~/Scripts/raycast/
#   - Native Login Item is managed at the host level via environment.loginItems
#
# NOT managed (Raycast stores these in encrypted SQLite):
#   - Extension installs/configs
#   - Extension hotkey bindings
#   - Cloud sync settings
#   - Raycast Beta installation (no Homebrew cask currently; keep /Applications/Raycast Beta.app installed manually)
#
# Note: Raycast Beta uses bundle id com.raycast-x.macos, while stable uses
# com.raycast.macos. Keep preferences written to both so switching channels is
# cheap and host login items decide which app starts.
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
  raycastPrefs = {
    raycastGlobalHotkey = "Command-49"; # ⌘Space
    raycastShouldFollowSystemAppearance = true;
    navigationCommandStyleIdentifierKey = "vim";
    onboardingCompleted = true;
    useHyperKeyIcon = true;
    raycastPreferredWindowMode = "compact";
    "raycastUI_preferredTextSize" = "large";
  };
in
{
  options.modules.desktop.apps.raycast = with types; {
    enable = mkBoolOpt false;
  };

  config = optionalAttrs isDarwin (
    mkIf cfg.enable {
      # Raycast Beta is intentionally not installed by Homebrew here: Homebrew
      # only ships the stable `raycast` cask, and installing it would recreate
      # /Applications/Raycast.app alongside /Applications/Raycast Beta.app.

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

        # Raycast preferences. Apply to stable and beta bundle IDs.
        "com.raycast.macos" = raycastPrefs;
        "com.raycast-x.macos" = raycastPrefs;
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
