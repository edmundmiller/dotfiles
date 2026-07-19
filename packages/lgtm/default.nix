{
  lib,
  fetchFromGitHub,
  git,
  rustPlatform,
}:

rustPlatform.buildRustPackage {
  pname = "lgtm";
  version = "0.1.0-unstable-2026-07-17";

  src = fetchFromGitHub {
    owner = "ellie";
    repo = "lgtm";
    rev = "573ffe1fb626ff86c47e8b0e99f1179f1bdc8a03";
    hash = "sha256-OtNieJRq+ekhOwU16WltRMdq71X7PyZpF9IvVPidwgQ=";
  };

  cargoHash = "sha256-zuSmy4qnbTZ7L/P0PY0wD77xsVEtuEop/LvjCqMNXL0=";

  # Nix's Apple SDK omits Xcode's proprietary Metal compiler.
  patches = [ ./patches/runtime-shaders.patch ];

  cargoBuildFlags = [ "--package=lgtm" ];
  cargoInstallFlags = [ "--package=lgtm" ];
  nativeCheckInputs = [ git ];

  postInstall = ''
    app="$out/Applications/LGTM.app/Contents"
    mkdir -p "$app/MacOS"
    mv "$out/bin/lgtm" "$app/MacOS/lgtm"
    rmdir "$out/bin"
    cat > "$app/Info.plist" <<'EOF'
    <?xml version="1.0" encoding="UTF-8"?>
    <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
    <plist version="1.0">
    <dict>
      <key>CFBundleName</key>
      <string>LGTM</string>
      <key>CFBundleDisplayName</key>
      <string>LGTM</string>
      <key>CFBundleIdentifier</key>
      <string>com.elliehuxtable.lgtm</string>
      <key>CFBundleExecutable</key>
      <string>lgtm</string>
      <key>CFBundlePackageType</key>
      <string>APPL</string>
      <key>CFBundleShortVersionString</key>
      <string>0.1.0</string>
      <key>CFBundleVersion</key>
      <string>573ffe1</string>
      <key>LSMinimumSystemVersion</key>
      <string>12.0</string>
      <key>NSHighResolutionCapable</key>
      <true/>
    </dict>
    </plist>
    EOF
  '';

  meta = {
    description = "Fast native code-review app built with GPUI";
    homepage = "https://github.com/ellie/lgtm";
    license = lib.licenses.mit;
    platforms = [ "aarch64-darwin" ];
  };
}
