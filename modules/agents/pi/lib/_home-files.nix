{
  builtins,
  configDir,
  concatenatedRules,
  piPkgDeps,
  piSettingsValidated,
  promptLinks,
  agentLinks,
  sessionSearchFiles,
}:

promptLinks
// agentLinks
// {
  ".pi/agent/AGENTS.md".text = concatenatedRules;
  ".pi/agent/settings.json".text = piSettingsValidated;
  ".pi/agent/keybindings.json".source = "${configDir}/pi/keybindings.json";
  ".pi/agent/pi-permissions.jsonc".source = "${configDir}/pi/pi-permissions.jsonc";
}
// sessionSearchFiles
// {
  ".pi/agent/extensions/pi-permission-system/config.json".text = builtins.toJSON {
    debugLog = false;
    permissionReviewLog = true;
    yoloMode = false;
  };
  ".pi/agent/extensions/enforce-commit-signing.ts".source =
    "${configDir}/pi/extensions/enforce-commit-signing.ts";
  ".pi/agent/extensions/process-info.ts".source = "${configDir}/pi/extensions/process-info.ts";
  ".pi/agent/extensions/critique.ts".source = "${configDir}/pi/extensions/critique.ts";
  ".pi/agent/extensions/commit-review.ts".source = "${configDir}/pi/extensions/commit-review.ts";
  ".pi/agent/extensions/review.ts".source = "${configDir}/pi/extensions/review.ts";
  ".pi/agent/extensions/lib/commit-review-logic.ts".source =
    "${configDir}/pi/extensions/lib/commit-review-logic.ts";
  ".pi/agent/extensions/lib/commit-config.ts".source =
    "${configDir}/pi/extensions/lib/commit-config.ts";
  ".pi/agent/extensions/lib/review-git.ts".source = "${configDir}/pi/extensions/lib/review-git.ts";
  ".pi/agent/extensions/lib/review-screen.ts".source =
    "${configDir}/pi/extensions/lib/review-screen.ts";
  ".pi/agent/extensions/generate-commit-message.ts".source =
    "${configDir}/pi/extensions/generate-commit-message.ts";
  ".pi/agent/extensions/tmux-status.ts".source = "${configDir}/pi/extensions/tmux-status.ts";
  ".pi/agent/extensions/sub-limits.ts".source = "${configDir}/pi/extensions/sub-limits.ts";
  ".pi/agent/extensions/pi-tool-display/config.json".text = builtins.toJSON {
    registerReadToolOverride = false;
    registerBashToolOverride = false;
    registerToolOverrides = {
      read = false;
      bash = false;
    };
  };

  ".pi/agent/extensions/prompt-url-widget.ts".source =
    "${configDir}/pi/extensions/prompt-url-widget.ts";
  ".pi/agent/extensions/you-are-right-killer.ts".source =
    "${configDir}/pi/extensions/you-are-right-killer.ts";
  ".pi/agent/rtk-config.json".source = "${configDir}/pi/extensions/rtk-config.json";
  ".pi/overwatch/config.json".text = ''
    {
      "dashboard": {
        "identity": "both",
        "showColumnHeader": true
      }
    }
  '';

  ".config/dotfiles/packages/pi-packages/pi-agentmap/node_modules".source =
    "${piPkgDeps.pi-agentmap}/node_modules";
  ".config/dotfiles/packages/pi-packages/pi-dcp/node_modules".source =
    "${piPkgDeps.pi-dcp}/node_modules";
}
