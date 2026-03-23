# critique — Pi-enabled fork of remorses/critique
#
# Tracks edmundmiller/critique because this fork:
# - flattens the upstream workspace into a single CLI package
# - adds `critique review --agent pi`
# - can load Pi session context from ~/.pi/agent/sessions JSONL fallbacks
# - hardens git diff invocation for repos with external diff tooling configured
{
  lib,
  buildNpmPackage,
  fetchFromGitHub,
  bun,
  makeWrapper,
}:

buildNpmPackage rec {
  pname = "critique";
  version = "0.1.108-unstable-2026-02-18";

  src = fetchFromGitHub {
    owner = "edmundmiller";
    repo = "critique";
    rev = "e0d5cada2199b35209b6f470a66e40bfd31fd992";
    hash = "sha256-M4XTmxtY2OXWgOJoABeJeJFyd/GztddLPg/wLUr0kBE=";
  };

  postPatch = ''
    cp ${./package-lock.json} package-lock.json
  '';

  nativeBuildInputs = [
    bun
    makeWrapper
  ];

  npmDepsHash = lib.fakeHash;

  dontNpmBuild = true;

  installPhase = ''
    runHook preInstall

    appDir=$out/lib/critique
    mkdir -p "$appDir" "$out/bin"

    cp -r src public package.json bunfig.toml node_modules "$appDir"/

    makeWrapper ${bun}/bin/bun $out/bin/critique \
      --add-flags "$appDir/src/cli.tsx" \
      --prefix PATH : ${lib.makeBinPath [ bun ]}

    runHook postInstall
  '';

  meta = with lib; {
    description = "Beautiful git diff viewer and AI review CLI, packaged from the Pi-enabled fork";
    homepage = "https://github.com/edmundmiller/critique";
    license = licenses.mit;
    mainProgram = "critique";
    platforms = platforms.all;
  };
}
