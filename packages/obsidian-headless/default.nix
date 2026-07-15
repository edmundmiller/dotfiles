{
  lib,
  buildNpmPackage,
  fetchzip,
  nodejs_22,
  python313,
}:

(buildNpmPackage.override { nodejs = nodejs_22; }) rec {
  pname = "obsidian-headless";
  version = "0.0.13";

  src = fetchzip {
    url = "https://registry.npmjs.org/obsidian-headless/-/obsidian-headless-${version}.tgz";
    hash = "sha256-waJjODrOlPFpe/egQU3GOLfsVkyr5dp+Tis9ELEafE8=";
  };

  postPatch = ''
    cp ${./package-lock.json} package-lock.json
  '';

  # better-sqlite3 uses prebuild-install (downloads prebuilt native binary)
  # python3 needed by node-gyp as fallback if prebuild not available
  nativeBuildInputs = [ python313 ];

  npmDepsFetcherVersion = 2;
  npmDepsHash = "sha256-ux/rE4KcbhgiEAO0V5Ph6z7tptZDhlo8tTLz8qLRL54=";

  dontNpmBuild = true;

  meta = with lib; {
    description = "Headless client for Obsidian Sync";
    homepage = "https://obsidian.md";
    license = licenses.unfree;
    mainProgram = "ob";
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
      "x86_64-darwin"
      "aarch64-darwin"
    ];
  };
}
