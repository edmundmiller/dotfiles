{ lib, buildNpmPackage }:

buildNpmPackage {
  pname = "flue-evlog";
  version = "0.1.0";
  src = lib.fileset.toSource {
    root = ./.;
    fileset = lib.fileset.unions [
      ./package.json
      ./package-lock.json
      ./tsconfig.json
      ./src
      ./README.md
      ./LICENSE
    ];
  };
  npmDepsHash = "sha256-lQx0lVbEGZnwgUgOzama7BEH+BseQRR11MKSA2EhQ6Y=";
  npmFlags = [ "--ignore-scripts" ];
  npmBuildScript = "build";
  meta = {
    description = "Flue model accounting through evlog drains";
    license = lib.licenses.mit;
    platforms = lib.platforms.unix;
  };
}
