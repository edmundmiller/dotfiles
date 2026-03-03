{
  lib,
  buildNpmPackage,
  fetchzip,
  python3,
}:

buildNpmPackage rec {
  pname = "obsidian-headless";
  version = "0.0.5";

  src = fetchzip {
    url = "https://registry.npmjs.org/obsidian-headless/-/obsidian-headless-${version}.tgz";
    hash = "sha256-t+8Vx39ETqtbxDHJcMjLrYefONCRLcpYhJMfYmranNo=";
  };

  postPatch = ''
    cp ${./package-lock.json} package-lock.json
  '';

  # better-sqlite3 uses prebuild-install (downloads prebuilt native binary)
  # python3 needed by node-gyp as fallback if prebuild not available
  nativeBuildInputs = [ python3 ];

  npmDepsHash = "sha256-wj0ezlDa7bKob96iuNPt9vtYO5HpRjqSLuo382jCGp8=";

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
