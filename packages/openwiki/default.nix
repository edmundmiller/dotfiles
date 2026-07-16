{
  inputs,
  lib,
  stdenv,
  fetchFromGitHub,
  fetchPnpmDeps,
  cctools,
  makeWrapper,
  node-gyp,
  nodejs_22,
  pnpm_10,
  pnpmConfigHook,
  python313,
  removeReferencesTo,
  srcOnly,
}:

let
  imsg =
    if stdenv.hostPlatform.isDarwin then
      inputs.nix-steipete-tools.packages.${stdenv.hostPlatform.system}.imsg
    else
      null;
in

stdenv.mkDerivation (finalAttrs: {
  pname = "openwiki";
  version = "0.1.2-unstable-2026-07-14";

  src = fetchFromGitHub {
    owner = "langchain-ai";
    repo = "openwiki";
    rev = "0c0639eece971acc75ccc36dad8d6b99a9b906f5";
    hash = "sha256-og/xDgW1f8/R7yTTjTTFidFgdBnXn85y+9HUwawfENY=";
  };

  patches = [
    ./patches/0001-configurable-personal-wiki-directory.patch
    ./patches/0002-imessage-connector.patch
  ];

  pnpmDeps = fetchPnpmDeps {
    inherit (finalAttrs) pname version src;
    pnpm = pnpm_10;
    fetcherVersion = 3;
    hash = "sha256-94ubDscIEItwkHzVbM4kUqTJpWFu5jpYJBUrhnyDJcA=";
  };

  nativeBuildInputs = [
    makeWrapper
    nodejs_22
    node-gyp
    pnpm_10
    pnpmConfigHook
    python313
    removeReferencesTo
  ]
  ++ lib.optionals stdenv.hostPlatform.isDarwin [
    cctools.libtool
  ];

  buildPhase = ''
    runHook preBuild
    pushd node_modules/.pnpm/better-sqlite3@12.11.1/node_modules/better-sqlite3
    npm run build-release --offline "--nodedir=${srcOnly nodejs_22}"
    find build -type f -exec ${removeReferencesTo}/bin/remove-references-to -t "${srcOnly nodejs_22}" {} \;
    popd

    pnpm rebuild esbuild
    pnpm build
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p "$out/lib/openwiki" "$out/bin"
    cp -r dist node_modules package.json "$out/lib/openwiki/"
    makeWrapper ${lib.getExe nodejs_22} "$out/bin/openwiki" \
      --add-flags "$out/lib/openwiki/dist/cli.js" \
      ${lib.optionalString stdenv.hostPlatform.isDarwin ''
        --prefix PATH : ${lib.makeBinPath [ imsg ]} \
        --set OPENWIKI_EXECUTABLE /run/current-system/sw/bin/openwiki
      ''}

    runHook postInstall
  '';

  meta = {
    description = "Agent-generated documentation wiki for codebases";
    homepage = "https://github.com/langchain-ai/openwiki";
    license = lib.licenses.mit;
    mainProgram = "openwiki";
    platforms = lib.platforms.unix;
  };
})
