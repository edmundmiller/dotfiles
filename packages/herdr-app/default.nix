{
  lib,
  stdenvNoCC,
  ghostty-bin,
  fetchurl,
  librsvg,
  writeTextDir,
}:
let
  # Official Herdr artwork, Apache-2.0, pinned independently of Ghostty.
  herdrLogo = fetchurl {
    url = "https://raw.githubusercontent.com/herdrdev/herdr/347f9c99bc95672e5ebcb26753648e85801d3c71/assets/logo.svg";
    hash = "sha256-9KhADVFfz1ARKpUqW0j1+m5rArTcsLSDypK+OffX96E=";
  };
  herdrConfig = writeTextDir "ghostty/config.ghostty" ''
    config-file = ~/.config/ghostty/herdr.conf
  '';
in
stdenvNoCC.mkDerivation {
  pname = "herdr-app";
  inherit (ghostty-bin) version;
  dontUnpack = true;
  dontFixup = true;

  installPhase = ''
    runHook preInstall
    mkdir -p "$out/Applications"
    cp -R ${ghostty-bin}/Applications/Ghostty.app "$out/Applications/Herdr.app"
    chmod -R u+w "$out/Applications/Herdr.app"
    app="$out/Applications/Herdr.app"
    plist="$app/Contents/Info.plist"
    /usr/bin/codesign --display --entitlements - --xml "$app" > entitlements.plist
    /usr/libexec/PlistBuddy -c 'Set :CFBundleIdentifier dev.edmundmiller.herdr' "$plist"
    /usr/libexec/PlistBuddy -c 'Set :CFBundleName Herdr' "$plist"
    /usr/libexec/PlistBuddy -c 'Set :CFBundleDisplayName Herdr' "$plist"
    # Explicitly initialize and activate the first window for the renamed app.
    /usr/libexec/PlistBuddy -c 'Set :LSEnvironment:GHOSTTY_MAC_LAUNCH_SOURCE cli' "$plist"
    /usr/libexec/PlistBuddy -c 'Add :LSEnvironment:GHOSTTY_HERDR_APP string 1' "$plist"
    /usr/libexec/PlistBuddy -c 'Add :LSEnvironment:XDG_CONFIG_HOME string ${herdrConfig}' "$plist"

    # A valid downstream trust root whose private key was discarded. Even manual
    # checks of Ghostty's hardcoded feed cannot install an upstream-signed update.
    /usr/libexec/PlistBuddy -c 'Set :SUPublicEDKey VZaGf1Sy2dJ8Je0lxq201yjxAbRnWwAdEHEJZ8Tejlc=' "$plist"
    /usr/libexec/PlistBuddy -c 'Add :SUVerifyUpdateBeforeExtraction bool true' "$plist"

    mkdir Herdr.iconset
    for size in 16 32 128 256 512; do
      ${librsvg}/bin/rsvg-convert -w "$size" -h "$size" \
        ${herdrLogo} -o "Herdr.iconset/icon_''${size}x''${size}.png"
      ${librsvg}/bin/rsvg-convert -w "$((size * 2))" -h "$((size * 2))" \
        ${herdrLogo} -o "Herdr.iconset/icon_''${size}x''${size}@2x.png"
    done
    /usr/bin/iconutil -c icns Herdr.iconset -o "$app/Contents/Resources/Herdr.icns"
    /usr/libexec/PlistBuddy -c 'Set :CFBundleIconFile Herdr.icns' "$plist"
    /usr/libexec/PlistBuddy -c 'Delete :CFBundleIconName' "$plist"

    # Do not claim Ghostty's URL handlers, services, or custom Dock icon plugin.
    for key in CFBundleURLTypes CFBundleDocumentTypes NSServices NSDockTilePlugIn; do
      /usr/libexec/PlistBuddy -c "Delete :$key" "$plist" || true
    done
    rm -rf "$app/Contents/PlugIns/DockTilePlugin.plugin"

    # Keep CFBundleExecutable unchanged: exec wrappers break AppKit registration.
    # Retain hardened runtime, except team-ID library validation which cannot work
    # for an ad-hoc-signed app. Other runtime protections stay enabled.
    /usr/libexec/PlistBuddy -c 'Add :com.apple.security.cs.disable-library-validation bool true' entitlements.plist
    /usr/bin/codesign --force --deep --sign - \
      "$app/Contents/Frameworks/Sparkle.framework"
    /usr/bin/codesign --force --sign - --options runtime \
      --entitlements entitlements.plist "$app"
    /usr/bin/codesign --verify --deep --strict "$app"
    runHook postInstall
  '';

  meta = {
    description = "Herdr workspace in a separate macOS Ghostty application";
    platforms = lib.platforms.darwin;
  };
}
