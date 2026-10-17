{
  lib,
  buildNpmPackage,
  fetchurl,
  nodejs,
}:

buildNpmPackage {
  pname = "vercel";
  version = "58.9.0";

  src = fetchurl {
    url = "https://registry.npmjs.org/vercel/-/vercel-58.9.0.tgz";
    hash = "sha512-CeQYOIR+wYyah2VJqWTRrz+P37vPXSV4pN0gfb9gKMtlFGahpPWChCIv74xBs8FggNe6rRKi5haaVssGI9QiyQ==";
  };

  # Keep the JS CLI and its pinned framework builders. The optional standalone
  # binaries duplicate Node and omit builders, fetching those later at runtime.
  postPatch = ''
    ${lib.getExe nodejs} -e "const fs = require('fs'); const pkg = JSON.parse(fs.readFileSync('package.json')); delete pkg.devDependencies; delete pkg.optionalDependencies; fs.writeFileSync('package.json', JSON.stringify(pkg));"
    cp ${./package-lock.json} package-lock.json
  '';

  npmDepsHash = "sha256-+fEksTWbvpof5AH6l17hQVQEWGoh4qq+ZUpDfLi669U=";
  npmDepsFetcherVersion = 2;
  dontNpmBuild = true;
  npmPackFlags = [ "--ignore-scripts" ];

  doInstallCheck = true;
  installCheckPhase = ''
    runHook preInstallCheck
    VERCEL_TELEMETRY_DISABLED=1 "$out/bin/vercel" --version | grep -F '58.9.0'
    runHook postInstallCheck
  '';

  meta = {
    description = "Vercel deployment CLI with framework builders";
    homepage = "https://github.com/vercel/vercel";
    license = lib.licenses.asl20;
    mainProgram = "vercel";
    platforms = lib.platforms.linux ++ lib.platforms.darwin;
  };
}
