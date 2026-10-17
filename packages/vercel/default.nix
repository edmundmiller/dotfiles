{
  lib,
  buildNpmPackage,
  fetchurl,
  nodejs,
  go,
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

  nativeBuildInputs = [ go ];
  # The Go builder otherwise compiles this helper beside its own JS on first
  # use, which cannot work once node_modules is in the read-only Nix store.
  postInstall = ''
    goBuilder="$out/lib/node_modules/vercel/node_modules/@vercel/go"
    GOCACHE="$TMPDIR/go-cache" GOTOOLCHAIN=local GOPROXY=off CGO_ENABLED=0 \
      go build -trimpath -o "$goBuilder/dist/analyze" "$goBuilder/analyze.go"
  '';

  doInstallCheck = true;
  installCheckPhase = ''
    runHook preInstallCheck
    VERCEL_TELEMETRY_DISABLED=1 "$out/bin/vercel" --version | grep -F '58.9.0'
    mkdir -p "$TMPDIR/go-analyzer-test"
    cat > "$TMPDIR/go-analyzer-test/handler.go" <<'GO'
    package handler
    import "net/http"
    func NotAHandler() {}
    func ServeHTTP(w http.ResponseWriter, r *http.Request) { w.Write([]byte("ok")) }
    GO
    test "$("$out/lib/node_modules/vercel/node_modules/@vercel/go/dist/analyze" \
      "-modpath=$TMPDIR/go-analyzer-test" "$TMPDIR/go-analyzer-test/handler.go")" \
      = '{"packageName":"handler","functionName":"ServeHTTP","watch":null}'
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
