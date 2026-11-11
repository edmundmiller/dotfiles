{
  lib,
  buildNpmPackage,
  fetchurl,
}:

buildNpmPackage rec {
  pname = "acpx";
  version = "0.12.0";

  src = fetchurl {
    url = "https://registry.npmjs.org/acpx/-/acpx-${version}.tgz";
    hash = "sha256-HdJxrQmjkHG4MFvc32rN2qMcjzXs8GPngtybXajhk9c=";
  };

  sourceRoot = "package";
  postPatch = ''
    cp ${./package.json} package.json
    cp ${./package-lock.json} package-lock.json
  '';

  npmDepsHash = "sha256-0TvSLWskVF/H+jp70KllawU83h4R9l+PxoCofyOxYvE=";
  npmDepsFetcherVersion = 2;
  dontNpmBuild = true;

  meta = {
    description = "Headless CLI client for the Agent Client Protocol";
    homepage = "https://github.com/openclaw/acpx";
    license = lib.licenses.mit;
    mainProgram = "acpx";
  };
}
