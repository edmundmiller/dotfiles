{
  lib,
  stdenv,
  fetchurl,
  makeWrapper,
  autoPatchelfHook,
}:
let
  version = "0.0.15";
  targets = {
    aarch64-darwin = {
      name = "darwin-arm64";
      hash = "sha512-eDNPUD/RILDp8IN3ueY1MuAdlreu8yJhJGQPHCMMHCraxPgl5oVxD4CQuZE6894h8P+gsIGa7NXSlPLgTFFCfQ==";
    };
    x86_64-linux = {
      name = "linux-x64-baseline";
      hash = "sha512-ZI7PsalhkdISb22MNayHufMXRXAdy8ntBGdM/96bCgyV4QRJnPbMmwNYOZntv1bfWYMF3UDdGu/Xgs0fV8nfUQ==";
    };
  };
  target = targets.${stdenv.hostPlatform.system};
in
stdenv.mkDerivation {
  pname = "opencode-browse";
  inherit version;

  src = fetchurl {
    url = "https://registry.npmjs.org/@opencode/browse-${target.name}/-/browse-${target.name}-${version}.tgz";
    inherit (target) hash;
  };
  sourceRoot = "package";
  dontBuild = true;
  dontStrip = true;
  nativeBuildInputs = [
    makeWrapper
  ]
  ++ lib.optionals stdenv.hostPlatform.isLinux [ autoPatchelfHook ];
  buildInputs = lib.optionals stdenv.hostPlatform.isLinux [ stdenv.cc.cc.lib ];

  installPhase = ''
    runHook preInstall
    install -Dm755 bin/browse "$out/libexec/browse"
    # Nix owns updates; never let the upstream installer replace this package.
    makeWrapper "$out/libexec/browse" "$out/bin/browse" \
      --set OPENCODE_BROWSER_AUTO_UPDATE off
    runHook postInstall
  '';

  doInstallCheck = true;
  installCheckPhase = ''
    runHook preInstallCheck
    export HOME="$TMPDIR/browse-home"
    mkdir -p "$HOME"
    "$out/bin/browse" --version | grep -Fx '${version}'
    "$out/bin/browse" --help >/dev/null
    runHook postInstallCheck
  '';

  meta = {
    description = "OpenCode Browse CLI and MCP server for your existing Chromium browser";
    homepage = "https://opencode.ai/product/browse";
    license = lib.licenses.mit;
    mainProgram = "browse";
    platforms = builtins.attrNames targets;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
  };
}
