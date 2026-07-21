{
  lib,
  buildNpmPackage,
  fetchFromGitHub,
  bun,
  nodejs,
}:

buildNpmPackage {
  pname = "herdr-tab-smart-rename";
  version = "0.1.1-omp";

  src = fetchFromGitHub {
    owner = "iurysza";
    repo = "herdr-tab-smart-rename";
    rev = "2db0c157c4ff9e7b6b8a7e15ccdbc62c5bd7a109";
    hash = "sha256-b/Cvxv2T/OvAzucPoPqDT058Kpv83heKtPNDu/SvqWc=";
  };

  patches = [
    ./patches/0001-use-omp-provider.patch
    ./patches/0002-autostart-packaged-worker.patch
  ];

  postPatch = ''
    cp ${./package-lock.json} package-lock.json
  '';

  npmDepsHash = "sha256-GPxUwWss4MTVVzs9FhZNlSGu5DYGUlPqcKxNnT5m0oY=";
  npmDepsFetcherVersion = 2;

  nativeBuildInputs = [ bun ];

  dontNpmBuild = true;
  doCheck = true;

  checkPhase = ''
    runHook preCheck
    bun test
    bun run check
    runHook postCheck
  '';

  installPhase = ''
    runHook preInstall

    ${lib.getExe nodejs} <<'NODE'
    const fs = require("fs");
    const path = require("path");
    const pkg = JSON.parse(fs.readFileSync("package.json", "utf8"));
    for (const name of Object.keys(pkg.devDependencies || {})) {
      fs.rmSync(path.join("node_modules", ...name.split("/")), {
        recursive: true,
        force: true,
      });
    }
    NODE
    find node_modules/.bin -xtype l -delete 2>/dev/null || true

    plugin_dir="$out/share/herdr/plugins/tab-smart-rename"
    mkdir -p "$plugin_dir"
    cp -R README.md docs herdr-plugin.toml provider.env.example src package.json node_modules "$plugin_dir/"

    runHook postInstall
  '';

  meta = {
    description = "Context-aware Herdr tab names using OMP provider authentication";
    homepage = "https://github.com/iurysza/herdr-tab-smart-rename";
    platforms = lib.platforms.linux ++ lib.platforms.darwin;
  };
}
