{
  lib,
  buildNpmPackage,
  fetchurl,
}:

buildNpmPackage rec {
  pname = "acpx";
  version = "0.5.3";

  src = fetchurl {
    url = "https://registry.npmjs.org/acpx/-/acpx-${version}.tgz";
    hash = "sha512-LNKc9gWlRztWKtQ3jr4g/kzlL9HU/5Wor79mromg/zRV5vE2FOdU+8VtW8ZypIMLzxLx2ATN6A4S1Dr97DM2QQ==";
  };

  sourceRoot = "package";
  postPatch = ''
    cp ${./package.json} package.json
    cp ${./package-lock.json} package-lock.json
  '';

  npmDepsHash = "sha256-BF8AJ9RA0WUYFv3BFaYfzv1TOWauF+G/Q/GiP6VChmM=";
  npmDepsFetcherVersion = 2;
  dontNpmBuild = true;

  meta = {
    description = "Headless CLI client for the Agent Client Protocol";
    homepage = "https://github.com/openclaw/acpx";
    license = lib.licenses.mit;
    mainProgram = "acpx";
  };
}
