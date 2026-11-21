{
  config,
  lib,
  pkgs,
  isDarwin,
  ...
}:
let
  cfg = config.modules.desktop.apps.hex;
  settingsFile = pkgs.writeText "hex-managed-settings.json" (builtins.toJSON cfg.settings);
  signedApp = "${config.user.home}/Applications/Hex.app";
  hexExecutable =
    if cfg.signingIdentity == null then "${pkgs.my.hex}/bin/hex" else "${signedApp}/Contents/MacOS/hex";
  signingSource = pkgs.writeText "hex-signing-source" "${pkgs.my.hex}\n${cfg.signingIdentity}\n";
in
{
  options.modules.desktop.apps.hex = {
    enable = lib.my.mkBoolOpt false;
    signingIdentity = lib.mkOption {
      type = lib.types.nullOr (lib.types.strMatching "[0-9A-Fa-f]{40}");
      default = null;
      description = ''
        SHA-1 fingerprint of an existing code-signing identity in the user's
        Keychain. Activation signs a copy in ~/Applications/Hex.app outside
        the Nix store. Null installs the package's ad-hoc-signed app instead.
      '';
    };
    settings = lib.mkOption {
      type = lib.types.attrsOf lib.types.anything;
      default = { };
      description = ''
        Preferences applied on activation using Hex's dotted settings keys.
        Unlisted preferences remain local. Do not put credentials here:
        these values are readable in the Nix store.
      '';
    };
  };

  config = lib.optionalAttrs isDarwin (
    lib.mkIf cfg.enable {
      # Do not register the ad-hoc app alongside the locally signed app.
      environment.systemPackages = [
        (
          if cfg.signingIdentity == null then
            pkgs.my.hex
          else
            pkgs.writeShellScriptBin "hex" ''
              exec ${lib.escapeShellArg hexExecutable} "$@"
            ''
        )
      ];
      home.configFile."hex/managed-settings.json".source = settingsFile;

      home-manager.users.${config.user.name} =
        { lib, ... }:
        {
          home.activation = {
            hexSettings =
              lib.hm.dag.entryAfter
                ([ "linkGeneration" ] ++ lib.optional (cfg.signingIdentity != null) "hexSigning")
                ''
                  # Use the running app's settings API; leave unlisted keys local.
                  run ${lib.escapeShellArg hexExecutable} settings apply ${settingsFile}
                '';
          }
          // lib.optionalAttrs (cfg.signingIdentity != null) {
            hexSigning = lib.hm.dag.entryAfter [ "copyApps" ] ''
              (
                set -e
                app=${lib.escapeShellArg signedApp}
                if [[ -v DRY_RUN ]]; then
                  echo "Hex signing: would sign and install $app"
                  exit 0
                fi
                marker="$app/Contents/Resources/nix-signing-source"
                requirement=${lib.escapeShellArg ''identifier "anomaly.hex" and certificate leaf = H"${cfg.signingIdentity}"''}
                if /usr/bin/cmp -s ${signingSource} "$marker" &&
                    /usr/bin/codesign --verify --deep --strict -R="$requirement" "$app"; then
                  echo "Hex signing: installed app already matches the package and identity"
                  exit 0
                fi
                if [ -e "$app" ] && [ ! -f "$marker" ]; then
                  echo "Hex signing: refusing to replace an unmanaged $app" >&2
                  exit 1
                fi

                /bin/mkdir -p "$HOME/Applications"
                stage=$(/usr/bin/mktemp -d "$HOME/Applications/.hex-signing.XXXXXX")
                trap '
                  if [ -d "$stage/previous.app" ] && [ ! -e "$app" ]; then
                    /bin/mv "$stage/previous.app" "$app" || exit 1
                  fi
                  /bin/rm -rf "$stage"
                ' EXIT
                source_app=${pkgs.my.hex}/Applications/Hex.app
                /usr/bin/ditto "$source_app" "$stage/Hex.app"
                /bin/chmod -R u+w "$stage/Hex.app"
                /bin/cp ${signingSource} "$stage/Hex.app/Contents/Resources/nix-signing-source"
                /usr/bin/codesign --display --entitlements :- "$source_app" > "$stage/entitlements.plist" 2>/dev/null
                /usr/bin/codesign --force --sign ${cfg.signingIdentity} \
                  --entitlements "$stage/entitlements.plist" "$stage/Hex.app"
                /usr/bin/codesign --verify --deep --strict -R="$requirement" "$stage/Hex.app"

                # Finish signing before touching the installed app. Keep the old
                # copy until the replacement is in place; never edit store files.
                if [ -e "$app" ]; then
                  /bin/mv "$app" "$stage/previous.app"
                fi
                /bin/mv "$stage/Hex.app" "$app"
                echo "Hex signing: installed $app; restart Hex to use this build"
              )
            '';
          };
        };
    }
  );
}
