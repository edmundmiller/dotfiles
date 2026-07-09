final: prev:
let
  version = "16.3.12";
  assets = {
    aarch64-darwin = {
      name = "omp-darwin-arm64";
      hash = "sha256-l7x4f75QMjWQKc7fw7lspCh9FoXJXguElLZLeXmkZvc=";
    };
    x86_64-darwin = {
      name = "omp-darwin-x64";
      hash = "sha256-WDmI3I/rnBloIz9cD9+9oIfhjkg8pJZrKw1k2cS448I=";
    };
    aarch64-linux = {
      name = "omp-linux-arm64";
      hash = "sha256-96AcQhttqbKFqhO2xtjl84c0e7QbBH6LnCzxrM4gsJg=";
    };
    x86_64-linux = {
      name = "omp-linux-x64";
      hash = "sha256-x8sBV2xpbZa5bCHWkegpRRGb87u3MW4+ifxbF+IH27c=";
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
