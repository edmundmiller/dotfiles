{
  lib,
  stdenvNoCC,
  fetchurl,
  autoPatchelfHook,
}:

let
  version = "0.11.1";

  sources = {
    "aarch64-darwin" = fetchurl {
      url = "https://github.com/modem-dev/hunk/releases/download/v${version}/hunkdiff-darwin-arm64.tar.gz";
      hash = "sha256-TjSrDxHjYXasXEr+O0Nid9PcJRvZIbRK/lP7DrGHtZo=";
    };
    "x86_64-linux" = fetchurl {
      url = "https://github.com/modem-dev/hunk/releases/download/v${version}/hunkdiff-linux-x64.tar.gz";
      hash = "sha256-XQkhUXxA9Vsd1ILgyo3cRqrOTfYNgVSUyiY9ZnQYchQ=";
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
