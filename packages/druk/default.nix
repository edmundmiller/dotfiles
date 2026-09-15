{
  fetchurl,
  lib,
  stdenvNoCC,
  unzip,
  autoPatchelfHook,
}:
let
  version = "1.27.2";
  sources = {
    aarch64-darwin = {
      archive = "druk-darwin-arm64.zip";
      hash = "sha256-O4Crt+TOjg3Ro/ZFjRNEpfp8NGOD6IUHevKPxQHI8VI=";
    };
    x86_64-darwin = {
      archive = "druk-darwin-x64.zip";
      hash = "sha256-vDeFDHfSAML2psGw5iPGGLCpHnzXcPX5b4rlESYaYTY=";
    };
    x86_64-linux = {
      archive = "druk-linux-x64.tar.gz";
      hash = "sha256-6XSaG7D/kOmvPstFXFeNJCGGm7IM8g1uAtUUnV505eA=";
    };
    aarch64-linux = {
      archive = "druk-linux-arm64.tar.gz";
      hash = "sha256-V3T9K2c8bwz1hgspap0ruwZ+rFiVEvrp4mYpAdh73bQ=";
    };
  };
  source =
    sources.${stdenvNoCC.hostPlatform.system}
      or (throw "druk: unsupported system ${stdenvNoCC.hostPlatform.system}");
in
stdenvNoCC.mkDerivation {
  pname = "druk";
  inherit version;

  src = fetchurl {
    url = "https://github.com/letstri/druk/releases/download/v${version}/${source.archive}";
    inherit (source) hash;
  };

  nativeBuildInputs =
    lib.optionals stdenvNoCC.hostPlatform.isDarwin [ unzip ]
    ++ lib.optionals stdenvNoCC.hostPlatform.isLinux [ autoPatchelfHook ];

  dontUnpack = true;
  dontStrip = true;

  installPhase = ''
    runHook preInstall
    mkdir -p unpacked
    case "$src" in
      *.zip) unzip -q "$src" -d unpacked ;;
      *) tar -xzf "$src" -C unpacked ;;
    esac
    install -Dm755 unpacked/druk "$out/bin/druk"
    if [ -f unpacked/THIRD_PARTY_NOTICES.md ]; then
      install -Dm644 unpacked/THIRD_PARTY_NOTICES.md \
        "$out/share/doc/druk/THIRD_PARTY_NOTICES.md"
    fi
    runHook postInstall
  '';

  meta = {
    description = "Terminal code editor";
    homepage = "https://github.com/letstri/druk";
    changelog = "https://github.com/letstri/druk/releases/tag/v${version}";
    license = lib.licenses.mit;
    mainProgram = "druk";
    platforms = builtins.attrNames sources;
  };
}
