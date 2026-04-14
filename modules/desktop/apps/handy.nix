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
  cfg = config.modules.desktop.apps.handy;

  handyBundleId = "com.pais.handy";
  handySettingsRelativePath = "Library/Application Support/${handyBundleId}/settings_store.json";

  seededSettings = recursiveUpdate {
    settings = {
      # Keys confirmed from Handy's shipped default_settings.json.
      push_to_talk = false;
      selected_language = "auto";

      # Keys confirmed from the app's persisted settings_store.json schema.
      app_language = "en-US";
      autostart_enabled = true;
      mute_while_recording = true;
      show_tray_icon = true;
      start_hidden = true;
    };
  } {
    settings = cfg.extraSettings;
  };

  seededSettingsFile = pkgs.writeText "handy-settings-store-seed.json" (builtins.toJSON seededSettings);
in
{
  options.modules.desktop.apps.handy = {
    enable = mkBoolOpt false;

    extraSettings = mkOption {
      type = types.attrsOf types.anything;
      default = { };
      description = ''
        Extra confirmed Handy `settings_store.json` keys to merge under `settings`.
        Keep machine-specific selections such as microphones or output devices in host config.
      '';
    };
  };

  config = optionalAttrs isDarwin (
    mkIf cfg.enable {
      # Install Handy via Homebrew cask (kept current upstream).
      homebrew.casks = [ "handy" ];

      home-manager.users.${config.user.name} =
        { lib, ... }:
        {
          home.activation.handySettings = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
            settings_file="$HOME/${handySettingsRelativePath}"
            settings_dir="$(dirname "$settings_file")"
            tmp_file="$(mktemp /tmp/handy-settings.XXXXXX)"

            mkdir -p "$settings_dir"

            if [ ! -f "$settings_file" ]; then
              printf '%s\n' '{"settings":{}}' > "$settings_file"
            fi

            # Handy's macOS bundle id is com.pais.handy, but v0.8.2 persists
            # confirmed settings in Application Support JSON, not a live defaults domain.
            ${pkgs.jq}/bin/jq -s 'reduce .[] as $item ({}; . * $item)' \
              "$settings_file" \
              "${seededSettingsFile}" > "$tmp_file"

            mv "$tmp_file" "$settings_file"
          '';
        };
    }
  );
}
