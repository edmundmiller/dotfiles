{
  lib,
  stdenv,
  buildNpmPackage,
  fetchurl,
  nodejs,
  makeWrapper,
  chromium,
}:

buildNpmPackage {
  pname = "excalidraw-cli";
  version = "0.2.0";

  # The published bundle includes renderer chunks and fonts, not just main.js.
  src = fetchurl {
    url = "https://registry.npmjs.org/@excalidraw/cli/-/cli-0.2.0.tgz";
    hash = "sha512-Qk1pQt8FMcbW//6XbhOvPSJVngE5NwgmHIb8X++m7ONwfHc01ortmWemDrBAMyolS1amGESmGbNBOK3hVb9otA==";
  };

  postPatch = ''
    ${lib.getExe nodejs} -e "const fs = require('fs'); const pkg = JSON.parse(fs.readFileSync('package.json')); delete pkg.devDependencies; fs.writeFileSync('package.json', JSON.stringify(pkg));"
    cp ${./package-lock.json} package-lock.json
  '';

  npmDepsHash = "sha256-NTb7d7xqtpQZw1SQih+RYq0sIIeMW9Qi80PzVWVRrPQ=";
  npmDepsFetcherVersion = 2;
  dontNpmBuild = true;
  npmPackFlags = [ "--ignore-scripts" ];

  nativeBuildInputs = [ makeWrapper ];
  # Darwin uses upstream discovery of an installed Chrome/Edge/Firefox, or
  # EXCALIDRAW_BROWSER_PATH / --browser-path. No browser download at activation.
  postFixup = lib.optionalString stdenv.hostPlatform.isLinux ''
    wrapProgram "$out/bin/excalidraw" \
      --set-default EXCALIDRAW_BROWSER_PATH ${lib.getExe chromium}
  '';

  doInstallCheck = true;
  installCheckPhase = ''
    runHook preInstallCheck
    "$out/bin/excalidraw" --version | grep -F '0.2.0'
    runHook postInstallCheck
  '';

  meta = {
    description = "Create, edit, and render Excalidraw diagrams";
    homepage = "https://github.com/excalidraw/cli";
    license = lib.licenses.mit;
    mainProgram = "excalidraw";
    platforms = lib.platforms.linux ++ lib.platforms.darwin;
  };
}
