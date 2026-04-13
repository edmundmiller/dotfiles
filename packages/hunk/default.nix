{
  lib,
  stdenvNoCC,
  fetchurl,
  autoPatchelfHook,
}:

let
  version = "0.9.2";

  sources = {
    "aarch64-darwin" = fetchurl {
      url = "https://github.com/modem-dev/hunk/releases/download/v${version}/hunkdiff-darwin-arm64.tar.gz";
      hash = "sha256-LpyFG+RlWuLaKR56lt53b2M8lnImyGSUK4bDQf6AW1E=";
    };
    "x86_64-linux" = fetchurl {
      url = "https://github.com/modem-dev/hunk/releases/download/v${version}/hunkdiff-linux-x64.tar.gz";
      hash = "sha256-eeHhlNH7of5LcoU79IaBJOmpZwdRkUPPTNtCfZCUAh8=";
    };
  };
in

stdenvNoCC.mkDerivation {
  pname = "hunk";
  inherit version;

  src =
    sources.${stdenvNoCC.hostPlatform.system}
      or (throw "unsupported system: ${stdenvNoCC.hostPlatform.system}");

  nativeBuildInputs = lib.optionals stdenvNoCC.hostPlatform.isLinux [ autoPatchelfHook ];

  sourceRoot = ".";

  installPhase = ''
    install -Dm755 hunkdiff-*/hunk $out/bin/hunk
  '';

  meta = with lib; {
    description = "Review-first terminal diff viewer for agent-authored changesets";
    homepage = "https://github.com/modem-dev/hunk";
    license = licenses.mit;
    mainProgram = "hunk";
    platforms = [
      "aarch64-darwin"
      "x86_64-linux"
    ];
  };
}
