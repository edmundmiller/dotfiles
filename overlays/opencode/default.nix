final: prev:
let
  platformArtifacts = {
    aarch64-darwin = {
      package = "cli-darwin-arm64";
      hash = "sha512-Q0g/Prm3FxTS70voyOEcrbNGX+TMVqQldoFmkYoYqq7eaVbIPNT1Wo/6YAqK2dvvnD0AGKq3ukZAzL//7D1riA==";
    };
    x86_64-linux = {
      package = "cli-linux-x64-baseline";
      hash = "sha512-QZcNjA7oLjU7Ad6JSBDiiA0ct/Df7nXJrz2DFOap1KSt/nUH6YtOyBlUW8yE5pnDPayRb04uI2KMdTsewgYLHA==";
    };
  };
  platform = final.stdenv.hostPlatform.system;
  artifact = platformArtifacts.${platform} or (throw "OpenCode v2 unsupported on ${platform}");
  linuxWrapperArgs = final.lib.optionalString final.stdenv.hostPlatform.isLinux "--prefix LD_LIBRARY_PATH : ${
    final.lib.makeLibraryPath [ final.stdenv.cc.cc.lib ]
  }";
  opencode = final.stdenv.mkDerivation rec {
    pname = "opencode";
    version = "0.0.0-next-15330";

    src = final.fetchurl {
      url = "https://registry.npmjs.org/@opencode-ai/${artifact.package}/-/${artifact.package}-${version}.tgz";
      inherit (artifact) hash;
    };

    sourceRoot = "package";
    dontBuild = true;
    nativeBuildInputs = [
      final.makeWrapper
    ]
    ++ final.lib.optionals final.stdenv.hostPlatform.isLinux [ final.autoPatchelfHook ];
    buildInputs = final.lib.optionals final.stdenv.hostPlatform.isLinux [ final.stdenv.cc.cc.lib ];
    dontStrip = true;

    installPhase = ''
      runHook preInstall
      mkdir -p "$out/bin" "$out/lib/opencode"
      cp -R bin/. "$out/lib/opencode/"
      makeWrapper "$out/lib/opencode/opencode2" "$out/bin/opencode" --run 'export XDG_CONFIG_HOME="''${XDG_CONFIG_HOME:-$HOME/.config/opencode2}"' ${linuxWrapperArgs}
      ln -s opencode "$out/bin/opencode2"
      runHook postInstall
    '';

    meta = {
      description = "OpenCode 2.0 beta CLI";
      homepage = "https://v2.opencode.ai/";
      license = final.lib.licenses.mit;
      mainProgram = "opencode";
      platforms = builtins.attrNames platformArtifacts;
    };
  };
in
{
  llm-agents = (prev.llm-agents or { }) // {
    inherit opencode;
  };
}
