final: prev:
let
  platformArtifacts = {
    aarch64-darwin = {
      package = "cli-darwin-arm64";
      hash = "sha512-1d5rC8+rMnsWNwSGyz3R+ePspoEYF6SB+HA9QcUDfdcYVyTR9wHXIqhbQ+87tfQZjxah4jtz+bi1E4+OIaC4bw==";
    };
    x86_64-linux = {
      package = "cli-linux-x64-baseline";
      hash = "sha512-p/xHg6VJrerJFGRtyN1fUYsYqbPyPEXHsDy0M8IIKGKVkJuPr34e8uyCIp8Het5UBlHp1Zkub6dsPPIyJwcJ7Q==";
    };
  };
  platform = final.stdenv.hostPlatform.system;
  artifact = platformArtifacts.${platform} or (throw "OpenCode v2 unsupported on ${platform}");
  linuxWrapperArgs = final.lib.optionalString final.stdenv.hostPlatform.isLinux "--prefix LD_LIBRARY_PATH : ${
    final.lib.makeLibraryPath [ final.stdenv.cc.cc.lib ]
  }";
  opencode = final.stdenv.mkDerivation rec {
    pname = "opencode";
    version = "1.18.18";

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
      makeWrapper "$out/lib/opencode/opencode2" "$out/bin/opencode" --run 'export XDG_CONFIG_HOME="''${XDG_CONFIG_HOME:-$HOME/.config}"' ${linuxWrapperArgs}
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
