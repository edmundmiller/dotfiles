{
  lib,
  stdenvNoCC,
  fetchurl,
  autoPatchelfHook,
  makeWrapper,
  clang,
}:
let
  version = "2.0.40";
  sources = {
    x86_64-linux = {
      platform = "linux-x64";
      hash = "sha256-yf+NZ72QP7atmia0PYpiwBAh3oKkTVXOSj3NRzIRPWs=";
    };
    aarch64-darwin = {
      platform = "darwin-arm64";
      hash = "sha256-sr4AOwQets/GUya+GPeesuC64hib55oYxQfmYbS2kAs=";
    };
  };
  source = sources.${stdenvNoCC.hostPlatform.system};
in
stdenvNoCC.mkDerivation {
  pname = "bend";
  inherit version;
  src = fetchurl {
    url = "https://github.com/bendlang/bend/releases/download/v${version}/bend-${version}-${source.platform}.tar.gz";
    inherit (source) hash;
  };
  nativeBuildInputs = [
    makeWrapper
  ]
  ++ lib.optionals stdenvNoCC.hostPlatform.isLinux [ autoPatchelfHook ];
  dontStrip = true;

  installPhase = ''
    runHook preInstall
    mkdir -p "$out"
    cp -R bin bend2 guide "$out/"
    # Real binary keeps its name so terminals (Rex) show "bend", not ".bend-wrapped".
    # It finds bend2 at dirname(execPath)/../bend2, so it must stay one level below $out.
    mkdir -p "$out/libexec"
    mv "$out/bin/bend" "$out/libexec/bend"
    makeWrapper "$out/libexec/bend" "$out/bin/bend" \
      --set BEND_NO_TELEMETRY 1 \
      --prefix PATH : ${lib.makeBinPath [ clang ]}
    runHook postInstall
  '';

  meta = {
    description = "Bend compiler with dependent types and parallel evaluation";
    homepage = "https://bend-lang.com";
    license = lib.licenses.asl20;
    mainProgram = "bend";
    platforms = builtins.attrNames sources;
  };
}
