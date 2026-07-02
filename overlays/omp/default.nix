final: prev:
let
  version = "16.3.2";
  assets = {
    aarch64-darwin = {
      name = "omp-darwin-arm64";
      hash = "sha256-7hSKoYj1wJLPQG5Fd++xfolzo2IkK5jYxSB7khSbLq8=";
    };
    x86_64-darwin = {
      name = "omp-darwin-x64";
      hash = "sha256-HmAuc7vh4eEKnPSS6P7w0ZyTziZ0vWqcvCFPE9mam+s=";
    };
    aarch64-linux = {
      name = "omp-linux-arm64";
      hash = "sha256-hft6kXDGTDetKK260guMPSsKIzxgSNyhG1Fe7T9D75E=";
    };
    x86_64-linux = {
      name = "omp-linux-x64";
      hash = "sha256-xIQ73IwAmMrEkaQ6bTEj3/r2DmNxDRu6ePC7qHa0Nyc=";
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
