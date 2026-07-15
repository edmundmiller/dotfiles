final: prev:
let
  platformArtifacts = {
    aarch64-darwin = {
      package = "cli-darwin-arm64";
      hash = "sha512-K9djPxU2mTX0ecbTYkVkmdhUegC47maCQFsrHZ82Tucg4Wl3OcspjpcyLa+Xqt0Ge8mGoW2cHv1PulJ6O4n9LQ==";
    };
    x86_64-linux = {
      package = "cli-linux-x64-baseline";
      hash = "sha512-6b9/qo+B7+VSc/JuCDEnc/29YHnxY4yMcrK/phUAE8km9rmNnngoS5kXZa1Dnzw00JmMpwRkC/ylNbkKU7kPZA==";
    };
  };
  platform = final.stdenv.hostPlatform.system;
  artifact = platformArtifacts.${platform} or (throw "OpenCode v2 unsupported on ${platform}");
  linuxWrapperArgs = final.lib.optionalString final.stdenv.hostPlatform.isLinux "--prefix LD_LIBRARY_PATH : ${
    final.lib.makeLibraryPath [ final.stdenv.cc.cc.lib ]
  }";
  opencode = final.stdenv.mkDerivation rec {
    pname = "opencode";
    version = "0.0.0-next-15586";

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
