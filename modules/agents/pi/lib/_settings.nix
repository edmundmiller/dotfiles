{
  config,
  cfg,
  lib,
  piSettingsParsed,
}:
let
  packageSource =
    pkg:
    if builtins.isString pkg then
      pkg
    else if builtins.isAttrs pkg && pkg ? source then
      pkg.source
    else
      "";

  # Keep module-specific Pi packages tied to the Nix modules that provide the
  # matching runtime. This prevents stale tools/skills from showing up on hosts
  # that do not run that shell integration, and avoids redundant interactive
  # shell prompts when tmux/herdr are the preferred persistent workspace layer.
  moduleManagedPackageGroups = {
    herdr = [ "npm:@ogulcancelik/pi-herdr" ];
    tmux = [
      "npm:pi-tmux-window-name"
      "git:github.com/ogulcancelik/pi-extensions"
      "https://github.com/pasky/pi-side-agents"
    ];
    interactiveShell = [ "npm:pi-interactive-shell" ];
    mcp = [
      "npm:pi-mcp-adapter"
      "npm:pi-mcporter"
    ];
    computerUse = [ "git:github.com/injaneity/pi-computer-use" ];
    gitTools = [
      "npm:@prinova/pi-github-tools"
      "npm:pi-gitnexus"
      "git:github.com/MattDevy/pi-extensions"
    ];
    statusUi = [
      "npm:@marckrenn/pi-sub-bar"
      "~/.pi/agent/extensions/sub-limits.ts"
      "git:github.com/Thinkscape/pi-status"
      "npm:pi-wakatime"
    ];
    contextMemory = [
      "npm:pi-context"
      "npm:pi-total-recall"
    ];
    cursorSdk = [
      # Cursor SDK provider: exposes Cursor models as `cursor/...` in Pi's native model picker.
      # https://github.com/fitchmultz/pi-cursor-sdk
      "npm:pi-cursor-sdk"
    ];
  };

  moduleManagedPackageSources = lib.concatLists (builtins.attrValues moduleManagedPackageGroups);

  dropModuleManagedPackages =
    packages:
    builtins.filter (pkg: !(builtins.elem (packageSource pkg) moduleManagedPackageSources)) packages;

  moduleManagedPackages =
    lib.optionals config.modules.shell.herdr.enable moduleManagedPackageGroups.herdr
    ++ lib.optionals config.modules.shell.tmux.enable [
      # Auto-name tmux windows + session titles from first prompt - https://github.com/default-anton/pi-tmux-window-name
      "npm:pi-tmux-window-name"
      # We're experimenting with tmux pane control for now (bash, capture, send, kill, spawn agents) - https://github.com/ogulcancelik/pi-extensions
      {
        source = "git:github.com/ogulcancelik/pi-extensions";
        extensions = [ "packages/pi-tmux/index.ts" ];
        skills = [ ];
      }
      # Side agents in tmux windows + git worktrees - https://github.com/pasky/pi-side-agents
      "https://github.com/pasky/pi-side-agents"
    ]
    ++ lib.optionals (
      !(config.modules.shell.tmux.enable || config.modules.shell.herdr.enable)
    ) moduleManagedPackageGroups.interactiveShell
    ++ lib.optionals cfg.mcp.enable moduleManagedPackageGroups.mcp
    ++ lib.optionals cfg.computerUse.enable moduleManagedPackageGroups.computerUse
    ++ lib.optionals cfg.gitTools.enable moduleManagedPackageGroups.gitTools
    ++ lib.optionals cfg.statusUi.enable moduleManagedPackageGroups.statusUi
    ++ lib.optionals cfg.contextMemory.enable moduleManagedPackageGroups.contextMemory
    ++ lib.optionals cfg.cursorSdk.enable moduleManagedPackageGroups.cursorSdk;

  piPackagesExtra =
    cfg.extraPackages
    ++ moduleManagedPackages
    ++ lib.optionals cfg.honcho.enable [ "npm:@agney/pi-honcho-memory" ];

  piSettingsBase =
    (
      piSettingsParsed
      // {
        packages = dropModuleManagedPackages piSettingsParsed.packages;
        enabledModels = lib.unique cfg.enabledModels;
      }
    )
    // lib.optionalAttrs config.modules.shell.herdr.enable (
      let
        herdrThemeName = config.modules.shell.herdr.piThemeName;
      in
      {
        # Herdr ships a matching high-contrast theme into ~/.pi/agent/themes.
        # Configure it directly in the generated Pi settings so activation does
        # not need to mutate the read-only Home Manager settings symlink.
        # The theme name varies by host (`piThemeVariant`), so read it from
        # the herdr module instead of hardcoding the default name here.
        theme = "light/${herdrThemeName}";
        themes = [ "${config.user.home}/.pi/agent/themes/${herdrThemeName}.json" ];
      }
    );

  piSettingsWithExtras =
    if piPackagesExtra == [ ] then
      piSettingsBase
    else
      piSettingsBase // { packages = piSettingsBase.packages ++ piPackagesExtra; };

  piSettingsPackageSources = map packageSource piSettingsWithExtras.packages;

  hasPiPackage = source: builtins.elem source piSettingsPackageSources;
in
{
  piSettingsValidated = builtins.toJSON piSettingsWithExtras;

  piConflictAssertions = [
    {
      assertion =
        !(
          hasPiPackage "~/.config/dotfiles/packages/pi-packages/pi-beads"
          && hasPiPackage "npm:@tintinweb/pi-tasks"
        );
      message = "Pi package conflict: both pi-beads and @tintinweb/pi-tasks register /tasks. Keep exactly one authoritative /tasks provider.";
    }
    {
      assertion =
        !(
          hasPiPackage "~/.config/dotfiles/packages/pi-packages/pi-non-interactive"
          && hasPiPackage "git:github.com/lucasmeijer/pi-bash-live-view"
        );
      message = "Pi package conflict: both pi-non-interactive and pi-bash-live-view register tool 'bash'. Keep exactly one authoritative bash provider.";
    }
  ];
}
