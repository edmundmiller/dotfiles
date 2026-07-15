# critique — remorses/critique with local Pi support patches
#
# We fetch the upstream repository and apply a small plain-diff patch stack
# exported from the fork. This keeps the upstream base explicit and makes the
# Pi-specific delta reviewable without keeping the fork around.
{
  lib,
  buildNpmPackage,
  fetchFromGitHub,
  bun,
  makeWrapper,
  nodejs,
}:

buildNpmPackage {
  pname = "critique";
  version = "0.1.141";

  src = fetchFromGitHub {
    owner = "remorses";
    repo = "critique";
    rev = "c959c484dca6ff443c24a5ffdd4a7d01218ab4cc";
    hash = "sha256-pZTqBw1yOHEQIv/w42JpuMruBjwu3CGa6MtEhGpG6F4=";
  };
  sourceRoot = "source/cli";

  patches = [
    ./patches/0001-add-agent-pi-support.patch
    ./patches/0002-no-ext-diff-and-pi-acp-fallback.patch
    ./patches/0003-add-typecheck-script.patch
    ./patches/0004-list-pi-sessions.patch
    ./patches/0005-load-pi-sessions-from-jsonl.patch
  ];

  postPatch = ''
    ${lib.getExe nodejs} -e "const fs=require('fs');const path='package.json';const pkg=require('./'+path);delete pkg.devDependencies;fs.writeFileSync(path, JSON.stringify(pkg, null, 2) + '\n')"
    cp ${./package-lock.json} package-lock.json
  '';
  npmInstallFlags = [ "--workspaces=false" ];

  nativeBuildInputs = [
    bun
    makeWrapper
  ];

  npmDepsHash = "sha256-I5VU7GLcqTZwYpuLO4DfS8cWulEEEpx3rTKtRhwq65Y=";
  npmDepsFetcherVersion = 2;

  dontNpmBuild = true;

  installPhase = ''
    runHook preInstall

    # We run the CLI directly from source with Bun, so keep the source tree,
    # but strip top-level devDependencies to avoid shipping the worker/test toolchain.
    # `npm prune --omit=dev` would be nicer here, but it tries to consult the npm cache
    # during the offline Nix build and fails for this package.
    node <<'NODE'
    const fs = require('fs');
    const path = require('path');

    const pkg = JSON.parse(fs.readFileSync('package.json', 'utf8'));
    for (const name of Object.keys(pkg.devDependencies || {})) {
      fs.rmSync(path.join('node_modules', ...name.split('/')), { recursive: true, force: true });
    }
    NODE
    find node_modules/.bin -xtype l -delete 2>/dev/null || true

    appDir=$out/lib/critique
    mkdir -p "$appDir" "$out/bin"

    cp -r src public package.json bunfig.toml node_modules "$appDir"/

    makeWrapper ${bun}/bin/bun $out/bin/critique \
      --add-flags "$appDir/src/cli.tsx"

    runHook postInstall
  '';

  meta = with lib; {
    description = "Beautiful git diff viewer and AI review CLI with Pi support patches applied on top of upstream";
    homepage = "https://github.com/remorses/critique";
    license = licenses.mit;
    mainProgram = "critique";
    platforms = platforms.all;
  };
}
