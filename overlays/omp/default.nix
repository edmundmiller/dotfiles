final: prev:
let
  version = "16.3.11";
  assets = {
    aarch64-darwin = {
      name = "omp-darwin-arm64";
      hash = "sha256-oRz4w623Msk/4ka6oHwjQIfE5x2SX3psYgTz2JU7Md4=";
    };
    x86_64-darwin = {
      name = "omp-darwin-x64";
      hash = "sha256-8fWcQdJnJJd5Ul7AGWc5i5ngnxLLpznsffjaMY5limA=";
    };
    aarch64-linux = {
      name = "omp-linux-arm64";
      hash = "sha256-Dqq4ldYkM/AJVUTodS4UPfu673c//BaL28fhU1oo4vM=";
    };
    x86_64-linux = {
      name = "omp-linux-x64";
      hash = "sha256-jZXU3jrhds1UtgMP3fM+KEdENzzdt4C4tP7Woa1j840=";
    };
  };
  asset =
    assets.${final.stdenv.hostPlatform.system}
      or (throw "Unsupported OMP system: ${final.stdenv.hostPlatform.system}");
  omp = final.stdenvNoCC.mkDerivation {
    pname = "omp";
    inherit version;
    dontUnpack = true;
    nativeBuildInputs = [ final.makeWrapper ];
    src = final.fetchurl {
      url = "https://github.com/can1357/oh-my-pi/releases/download/v${version}/${asset.name}";
      sha256 = asset.hash;
    };
    installPhase = ''
      runHook preInstall

      install -Dm755 "$src" "$out/lib/omp/omp"
      makeWrapper "$out/lib/omp/omp" "$out/bin/omp" \
        --set PI_SKIP_VERSION_CHECK 1

      runHook postInstall
    '';
    meta = {
      description = "Oh My Pi coding agent";
      homepage = "https://omp.sh";
      mainProgram = "omp";
      platforms = builtins.attrNames assets;
    };
  };
in
{
  llm-agents = (prev.llm-agents or { }) // {
    inherit omp;
  };
}
