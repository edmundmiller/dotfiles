{
  lib,
  buildNpmPackage,
  fetchzip,
  python3,
}:

buildNpmPackage rec {
  pname = "diffity";
  version = "0.5.3";

  src = fetchzip {
    url = "https://registry.npmjs.org/diffity/-/diffity-${version}.tgz";
    hash = "sha256-2K6eiLrTDSoL7YdT4TceL1PQZesARXD5CqCfuFpztU0=";
  };

  postPatch = ''
    cp ${./package-lock.json} package-lock.json
  '';

  # better-sqlite3 may need to build from source when prebuilt binaries
  # are unavailable in the sandbox.
  nativeBuildInputs = [ python3 ];

  npmDepsHash = "sha256-CshXg5aoq1D+XTzVWVwZ6URISuPzeeFPhaV6EPGoDX4=";

  dontNpmBuild = true;

  meta = with lib; {
    description = "Agent-agnostic GitHub-style diff viewer and code review tool";
    homepage = "https://github.com/kamranahmedse/diffity";
    license = licenses.unfree;
    mainProgram = "diffity";
    platforms = platforms.unix;
  };
}
