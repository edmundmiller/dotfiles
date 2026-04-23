{
  config,
  lib,
  pkgs,
  isDarwin,
  ...
}:
with lib;
with lib.my;
let
  cfg = config.modules.editors.zed;

  zedSettingsPath = "${config.dotfiles.configDir}/zed/settings.json";
  zedSettingsRaw =
    if builtins.pathExists zedSettingsPath then builtins.readFile zedSettingsPath else null;

  # settings.json is JSONC (leading // comments), so strip full-line comments
  # before parsing it at eval time for lightweight schema validation.
  isCommentLine =
    line:
    lib.hasPrefix "//" (
      lib.trimWith {
        start = true;
        end = false;
      } line
    );
  zedSettingsStripped =
    if zedSettingsRaw == null then
      null
    else
      lib.concatStringsSep "\n" (
        builtins.filter (line: !isCommentLine line) (lib.splitString "\n" zedSettingsRaw)
      );

  zedSettingsParsed =
    if zedSettingsStripped == null then
      {
        success = false;
        value = { };
      }
    else
      builtins.tryEval (builtins.fromJSON zedSettingsStripped);

  zedSettings = if zedSettingsParsed.success then zedSettingsParsed.value else { };

  playSoundWhenDone = lib.attrByPath [ "agent" "play_sound_when_agent_done" ] null zedSettings;
  isPlaySoundWhenDoneValid =
    if playSoundWhenDone == null then
      true
    else
      builtins.isString playSoundWhenDone
      && builtins.elem playSoundWhenDone [
        "never"
        "when_hidden"
        "always"
      ];

  toolPermissionDefault = lib.attrByPath [ "agent" "tool_permissions" "default" ] null zedSettings;
  isToolPermissionDefaultValid =
    if toolPermissionDefault == null then
      true
    else
      builtins.isString toolPermissionDefault
      && builtins.elem toolPermissionDefault [
        "allow"
        "deny"
        "confirm"
      ];

  relativeLineNumbers = lib.attrByPath [ "relative_line_numbers" ] null zedSettings;
  isRelativeLineNumbersValid =
    if relativeLineNumbers == null then
      true
    else
      builtins.isString relativeLineNumbers
      && builtins.elem relativeLineNumbers [
        "disabled"
        "enabled"
        "wrapped"
      ];

  autosaveSetting = lib.attrByPath [ "autosave" ] null zedSettings;
  isAutosaveValid =
    if autosaveSetting == null then
      true
    else if builtins.isString autosaveSetting then
      builtins.elem autosaveSetting [
        "off"
        "on_focus_change"
        "on_window_change"
      ]
    else if builtins.isAttrs autosaveSetting then
      let
        afterDelay = autosaveSetting.after_delay or null;
      in
      builtins.isAttrs afterDelay && builtins.isInt (afterDelay.milliseconds or null)
    else
      false;

  zedSchemaAssertions = [
    {
      assertion = builtins.pathExists zedSettingsPath;
      message = "Zed schema check: settings file not found at ${zedSettingsPath}";
    }
    {
      assertion = zedSettingsParsed.success;
      message = "Zed schema check: ${zedSettingsPath} is invalid JSONC/JSON";
    }
    {
      assertion = isPlaySoundWhenDoneValid;
      message = ''
        Zed schema check: agent.play_sound_when_agent_done must be one of
        "never", "when_hidden", or "always".
      '';
    }
    {
      assertion = isToolPermissionDefaultValid;
      message = ''
        Zed schema check: agent.tool_permissions.default must be one of
        "allow", "deny", or "confirm".
      '';
    }
    {
      assertion = isRelativeLineNumbersValid;
      message = ''
        Zed schema check: relative_line_numbers must be one of
        "disabled", "enabled", or "wrapped".
      '';
    }
    {
      assertion = isAutosaveValid;
      message = ''
        Zed schema check: autosave must be one of
        "off", "on_focus_change", "on_window_change", or
        { "after_delay": { "milliseconds": <int> } }.
      '';
    }
  ];
in
{
  options.modules.editors.zed = {
    enable = mkBoolOpt false;
  };

  config = mkIf cfg.enable (mkMerge [
    {
      assertions = zedSchemaAssertions;
    }

    (mkIf (!isDarwin) {
      home-manager.users.${config.user.name}.programs.zed-editor = {
        enable = true;
        package = pkgs.zed-editor;
        installRemoteServer = true;
      };
    })

    (mkIf isDarwin {
      homebrew.casks = [ "zed" ];

      modules.editors.file-associations = {
        enable = mkDefault true;
        editor = mkDefault "zed";
      };
    })
  ]);
}
