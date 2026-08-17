{
  lib,
  buildNpmPackage,
  importNpmLock,
  inputs,
}:

let
  version = "1.78.0";
  upstreamPluginVersion =
    (builtins.fromJSON (builtins.readFile (inputs.anti-slop + /package.json)))
    .dependencies."@oxlint/plugins";
in
assert lib.assertMsg (upstreamPluginVersion == version) ''
  anti-slop expects @oxlint/plugins ${upstreamPluginVersion}; update this package and the pinned oxlint together.
'';
buildNpmPackage {
  pname = "anti-slop";
  inherit version;

  src = inputs.anti-slop;

  postPatch = ''
    cp ${./package.json} package.json
    cp ${./package-lock.json} package-lock.json
  '';

  npmDeps = importNpmLock { npmRoot = ./.; };
  npmConfigHook = importNpmLock.npmConfigHook;
  dontNpmBuild = true;

  installPhase = ''
    runHook preInstall

    pluginDir=$out/lib/anti-slop
    mkdir -p "$pluginDir"
    cp -r src/. "$pluginDir/"
    cp -r node_modules "$pluginDir/"

    runHook postInstall
  '';

  meta = {
    description = "Opinionated Oxlint rules that reject low-evidence code patterns";
    homepage = "https://github.com/dmmulroy/anti-slop";
    license = lib.licenses.mit;
    platforms = lib.platforms.all;
  };
}
