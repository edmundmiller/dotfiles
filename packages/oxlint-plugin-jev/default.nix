{
  lib,
  buildNpmPackage,
  importNpmLock,
  nodejs_22,
  runtimeShell,
  writeText,
}:

let
  nodejs = nodejs_22;
  manifest = builtins.fromJSON (builtins.readFile ./package.json);
  jevVersion = manifest.dependencies."oxlint-plugin-jev";
  oxlintVersion = manifest.dependencies.oxlint;
  jevRules = builtins.fromJSON (builtins.readFile ./rules.json);
  ignorePatterns = [
    ".agents/**"
    ".claude/**"
    ".codex/**"
    ".omp/**"
    ".opencode/**"
    ".pi/**"
  ];
  configTemplate = writeText "oxlint-jev.json" (
    builtins.toJSON {
      inherit ignorePatterns;
      categories = {
        correctness = "off";
        nursery = "off";
        pedantic = "off";
        perf = "off";
        restriction = "off";
        style = "off";
        suspicious = "off";
      };
      jsPlugins = [
        {
          name = "jev";
          specifier = "@jevSpecifier@";
        }
      ];
      rules = {
        "jev/ask" = [
          "error"
          {
            ci = "skip";
            rules = jevRules;
          }
        ];
      };
    }
  );
in
assert lib.assertMsg (jevVersion == "0.1.1") ''
  oxlint-plugin-jev is pinned at 0.1.1; update package.json and package-lock.json together.
'';
assert lib.assertMsg (oxlintVersion == "1.83.0") ''
  jev needs oxlint 1.83.0 or newer. Keep the CLI pin aligned with the plugin.
'';
(buildNpmPackage.override { inherit nodejs; }) {
  pname = "oxlint-plugin-jev";
  version = jevVersion;

  src = lib.fileset.toSource {
    root = ./.;
    fileset = lib.fileset.unions [
      ./package.json
      ./package-lock.json
    ];
  };

  npmDeps = importNpmLock { npmRoot = ./.; };
  inherit (importNpmLock) npmConfigHook;
  dontNpmBuild = true;

  installPhase = ''
    runHook preInstall

    pluginRoot=$out/lib/oxlint-jev
    mkdir -p "$pluginRoot" "$out/bin" "$out/share"
    cp -a node_modules "$pluginRoot/"
    cp package.json "$pluginRoot/"

    specifier="$pluginRoot/node_modules/oxlint-plugin-jev/dist/index.mjs"
    if [ ! -f "$specifier" ]; then
      echo "oxlint-plugin-jev entry missing: $specifier" >&2
      exit 1
    fi

    substitute ${configTemplate} "$out/share/oxlint-jev.json" \
      --replace-fail '@jevSpecifier@' "$specifier"

    substitute ${./oxlint-jev.sh} "$out/bin/oxlint-jev" \
      --replace-fail '@runtimeShell@' ${lib.escapeShellArg runtimeShell} \
      --replace-fail '@nodejsBin@' ${lib.escapeShellArg (lib.makeBinPath [ nodejs ])} \
      --replace-fail '@oxlintBin@' "$out/lib/oxlint-jev/node_modules/oxlint/bin/oxlint" \
      --replace-fail '@jevConfig@' "$out/share/oxlint-jev.json"
    chmod +x "$out/bin/oxlint-jev"

    runHook postInstall
  '';

  doInstallCheck = true;
  nativeCheckInputs = [ nodejs ];
  installCheckPhase = ''
    runHook preInstallCheck
    echo 'export function add(left: number, right: number): number { return left + right }' > smoke.ts
    "$out/bin/oxlint-jev" smoke.ts
    runHook postInstallCheck
  '';

  meta = {
    description = "Opt-in Oxlint wrapper that asks TypeSafe Jev plain-English rules";
    homepage = "https://github.com/wobsoriano/oxlint-plugin-jev";
    license = lib.licenses.mit;
    mainProgram = "oxlint-jev";
    platforms = lib.platforms.unix;
  };
}
