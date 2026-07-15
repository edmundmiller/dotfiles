{
  lib,
  stdenv,
  fetchFromGitHub,
  fetchurl,
  mesa,
  fontconfig,
  htslib,
  glfw,
  curl,
  pkg-config,
}:
let
  skiaArtifacts = {
    aarch64-darwin = {
      url = "https://github.com/kcleal/skia_build_arm64/releases/download/v0.1.0/skia-m133-macos-Release-arm64.tar.gz";
      hash = "sha256-UIkgVZ8+A+JcaFlVpPfaoBEOud98IVsObH3klzw4aBc=";
    };
    x86_64-darwin = {
      url = "https://github.com/kcleal/skia_build_arm64/releases/download/v0.1.0/skia-m133-macos-Release-x64.tar.gz";
      hash = "sha256-CsDMh9b888cpL4UkryFk3TqExDwTgBBGFEs/mElvtHc=";
    };
    aarch64-linux = {
      url = "https://github.com/kcleal/skia_build_arm64/releases/download/v0.1.0/skia-m133-linux-Release-arm64.tar.gz";
      hash = "sha256-szR9e49ThaHpWztIG4RRPssB8tfPQZPXRJPG3Gm9Unc=";
    };
    x86_64-linux = {
      url = "https://github.com/kcleal/skia_build_arm64/releases/download/v0.1.0/skia-m133-linux-Release-x64.tar.gz";
      hash = "sha256-IUaLWV/wLuKaCq/KORcWXdB0WSqSSDJ54P4uZTlKVp4=";
    };
  };
in
stdenv.mkDerivation rec {
  pname = "gw";
  version = "1.2.6";

  src = fetchFromGitHub {
    owner = "kcleal";
    repo = "gw";
    rev = "v${version}";
    hash = "sha256-zRxJFS4LY++LJC1wKsNx4YTdjvuS9OPW2P1uJmaLdNo=";
  };
  skia = fetchurl skiaArtifacts.${stdenv.hostPlatform.system};

  nativeBuildInputs = [ pkg-config ];

  # https://kcleal.github.io/gw/docs/install/Linux.html#building-from-source
  buildInputs = [
    mesa # libgl1-mesa-dev
    fontconfig # libfontconfig-dev
    htslib # libhts-dev
    glfw
    curl
  ];

  postPatch = ''
    mkdir -p lib/skia
    tar -xf ${skia} -C lib/skia
  '';

  installPhase = ''
    runHook preInstall
    install -Dm755 gw "$out/bin/gw"
    runHook postInstall
  '';

  meta = with lib; {
    description = "Genome browser and variant annotation";
    homepage = "https://github.com/kcleal/gw";
    license = licenses.mit;
    maintainers = with maintainers; [ edmundmiller ];
    mainProgram = "gw";
    platforms = builtins.attrNames skiaArtifacts;
  };
}
