{
  lib,
  buildNpmPackage,
  fetchurl,
  makeWrapper,
  nodejs,
}:

buildNpmPackage rec {
  pname = "stack";
  version = "0.1.3";

  src = fetchurl {
    url = "https://registry.npmjs.org/@kitlangton/stack/-/stack-${version}.tgz";
    hash = "sha256-4bYSsictBYKA+GMr2gT8YCkOADaLtAbVpK97hzhBI+c=";
  };

  postPatch = ''
    cp ${./package-lock.json} package-lock.json
    node -e 'const fs = require("fs"); const pkg = JSON.parse(fs.readFileSync("package.json", "utf8")); delete pkg.devDependencies; fs.writeFileSync("package.json", JSON.stringify(pkg, null, 2));'
  '';

  npmDepsHash = "sha256-bJO3+X7471dba72CoOlA21g6gclsgKFKhTZLssQ9fDM=";
  npmDepsFetcherVersion = 2;
  npmFlags = [
    "--omit=dev"
    "--legacy-peer-deps"
  ];
  dontNpmBuild = true;

  nativeBuildInputs = [ makeWrapper ];

  installPhase = ''
    runHook preInstall

    mkdir -p $out/lib/node_modules/@kitlangton/stack $out/bin
    cp -R . $out/lib/node_modules/@kitlangton/stack

    makeWrapper ${nodejs}/bin/node $out/bin/stack \
      --add-flags $out/lib/node_modules/@kitlangton/stack/dist/cli.js

    runHook postInstall
  '';

  meta = {
    description = "Squash-safe stacked PR repair CLI";
    homepage = "https://github.com/kitlangton/stack";
    license = lib.licenses.mit;
    mainProgram = "stack";
  };
}
