{
  lib,
  stdenvNoCC,
  fetchurl,
  autoPatchelfHook,
  git,
}:

let
  version = "1.1.8";

  sources = {
    "x86_64-linux" = fetchurl {
      url = "https://usegitai.com/worker/releases/download/v${version}/git-ai-linux-x64";
      hash = "sha256-I9KkzigP55SKCLJEmVw3oyxD+2M0kV26qKMQVzDsB8I=";
    };
    "x86_64-darwin" = fetchurl {
      url = "https://usegitai.com/worker/releases/download/v${version}/git-ai-macos-x64";
      hash = "sha256-VDAiwDm3ID06jwUejJ5/8SwkpDHfvoWU03WVmx8tbm0=";
    };
    "aarch64-darwin" = fetchurl {
      url = "https://usegitai.com/worker/releases/download/v${version}/git-ai-macos-arm64";
      hash = "sha256-js756hsRCm+8ugVwwUfkxlsH4E5ghsz2k6slu/MMHDY=";
    };
  };
in
stdenvNoCC.mkDerivation {
  pname = "git-ai";
  inherit version;

  src =
    sources.${stdenvNoCC.hostPlatform.system}
      or (throw "Unsupported platform: ${stdenvNoCC.hostPlatform.system}");

  dontUnpack = true;

  nativeBuildInputs = lib.optionals stdenvNoCC.hostPlatform.isLinux [ autoPatchelfHook ];

  installPhase = ''
    runHook preInstall

    install -Dm755 $src $out/bin/git-ai

    # Symlink git-og to real git so git-ai can find it
    ln -s ${git}/bin/git $out/bin/git-og

    runHook postInstall
  '';

  meta = with lib; {
    description = "AI-powered git extension with context layer and ai-blame";
    homepage = "https://usegitai.com";
    license = licenses.unfree;
    maintainers = [ ];
    mainProgram = "git-ai";
    platforms = [
      "x86_64-linux"
      "x86_64-darwin"
      "aarch64-darwin"
    ];
  };
}
