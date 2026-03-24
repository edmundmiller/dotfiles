# zele — remorses/zele with local fork patches
#
# Fetch upstream source and apply the small plain-diff patch stack exported
# from the former fork so the fork can be deleted without losing the changes.
{
  lib,
  buildNpmPackage,
  fetchFromGitHub,
  bun,
  makeWrapper,
  prisma-engines,
  sqlite,
}:

buildNpmPackage {
  pname = "zele";
  version = "0.3.13-unstable-2026-02-15";

  src = fetchFromGitHub {
    owner = "remorses";
    repo = "zele";
    rev = "0892b8452e7b640d656b73d71f8402e93421ecc1";
    hash = "sha256-yB809F1n6qrTIeAR32Nmcra1Ci0KHI0J3Hz/gqbHG3U=";
  };

  patches = [
    ./patches/0001-add-nix-flake-and-development-guide.patch
    ./patches/0002-suppress-browser-opener-spawn-errors.patch
    ./patches/0003-resolve-oauth-client-by-key-name.patch
  ];

  postPatch = ''
    cp ${./package-lock.json} package-lock.json
  '';

  nativeBuildInputs = [
    bun
    makeWrapper
    sqlite
  ];

  PRISMA_QUERY_ENGINE_BINARY = "${prisma-engines}/bin/query-engine";
  PRISMA_SCHEMA_ENGINE_BINARY = "${prisma-engines}/bin/schema-engine";
  PRISMA_MIGRATION_ENGINE_BINARY = "${prisma-engines}/bin/migration-engine";
  PRISMA_FMT_BINARY = "${prisma-engines}/bin/prisma-fmt";

  npmDepsHash = "sha256-it4KNnG4jjaYkQXvzKUyqBElfPq7JahdTgcK8P5x3Sg=";

  npmBuildScript = "build";

  installPhase = ''
    runHook preInstall

    # Keep the built app self-contained for Bun at runtime, but drop obvious
    # top-level dev-only packages after the build has finished.
    node <<'NODE'
    const fs = require('fs');
    const path = require('path');

    const pkg = JSON.parse(fs.readFileSync('package.json', 'utf8'));
    for (const name of Object.keys(pkg.devDependencies || {})) {
      fs.rmSync(path.join('node_modules', ...name.split('/')), { recursive: true, force: true });
    }
    NODE
    find node_modules/.bin -xtype l -delete 2>/dev/null || true

    appDir=$out/lib/zele
    mkdir -p "$appDir/src" "$out/bin"

    cp -r dist node_modules package.json "$appDir"/
    cp src/schema.sql "$appDir/src/"

    makeWrapper ${bun}/bin/bun $out/bin/zele \
      --add-flags "$appDir/dist/cli.js"

    runHook postInstall
  '';

  meta = with lib; {
    description = "Terminal Gmail/calendar client with local fork fixes applied on top of upstream";
    homepage = "https://github.com/remorses/zele";
    license = licenses.isc;
    mainProgram = "zele";
    platforms = platforms.all;
  };
}
