{
  lib,
  stdenv,
  fetchFromGitHub,
  fetchPnpmDeps,
  cctools,
  makeWrapper,
  node-gyp,
  nodejs,
  pnpm_10,
  pnpmConfigHook,
  python3,
  removeReferencesTo,
  srcOnly,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "openwiki";
  version = "0.1.2-unstable-2026-07-13";

  src = fetchFromGitHub {
    owner = "langchain-ai";
    repo = "openwiki";
    rev = "7c084f9f6f8032243fd3dfd544969c279416b5cb";
    hash = "sha256-sMxxn3PDA+0qJK26VguVbZAY+jUaAwA+m+OZGPMESJ0=";
  };

  patches = [
    ./patches/0001-configurable-personal-wiki-directory.patch
  ];

  pnpmDeps = fetchPnpmDeps {
    inherit (finalAttrs) pname version src;
    pnpm = pnpm_10;
    fetcherVersion = 2;
    hash = "sha256-xN/OKHGzXoW8GKwLbLKq5PGabWEa+Y1aZtS5L3SxH/g=";
  };

  nativeBuildInputs = [
    makeWrapper
    nodejs
    node-gyp
    pnpm_10
    pnpmConfigHook
    python3
    removeReferencesTo
  ]
  ++ lib.optionals stdenv.hostPlatform.isDarwin [
    cctools.libtool
  ];

  buildPhase = ''
    runHook preBuild
    pushd node_modules/.pnpm/better-sqlite3@12.11.1/node_modules/better-sqlite3
    npm run build-release --offline "--nodedir=${srcOnly nodejs}"
    find build -type f -exec ${removeReferencesTo}/bin/remove-references-to -t "${srcOnly nodejs}" {} \;
    popd

    pnpm rebuild esbuild
    pnpm build
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p "$out/lib/openwiki" "$out/bin"
    cp -r dist node_modules package.json "$out/lib/openwiki/"
    makeWrapper ${lib.getExe nodejs} "$out/bin/openwiki" \
      --add-flags "$out/lib/openwiki/dist/cli.js"

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
