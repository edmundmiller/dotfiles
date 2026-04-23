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

  # Validate that a nested JSONC field is one of the allowed string values.
  # Returns an assertion attrset { assertion; message; }.
  mkEnumAssertion =
    name: path: allowed:
    let
      val = lib.attrByPath path null zedSettings;
      quoted = map (v: ''"${v}"'') allowed;
    in
    {
      assertion = val == null || (builtins.isString val && builtins.elem val allowed);
      message = "Zed schema check: ${name} must be one of ${lib.concatStringsSep ", " quoted}.";
    };

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
      autosaveSetting ? after_delay
      && builtins.isAttrs autosaveSetting.after_delay
      && autosaveSetting.after_delay ? milliseconds
      && builtins.isInt autosaveSetting.after_delay.milliseconds
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
    (mkEnumAssertion "agent.play_sound_when_agent_done" [ "agent" "play_sound_when_agent_done" ] [
      "never"
      "when_hidden"
      "always"
    ])
    (mkEnumAssertion "agent.tool_permissions.default" [ "agent" "tool_permissions" "default" ] [
      "allow"
      "deny"
      "confirm"
    ])
    (mkEnumAssertion "relative_line_numbers" [ "relative_line_numbers" ] [
      "disabled"
      "enabled"
      "wrapped"
    ])
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
