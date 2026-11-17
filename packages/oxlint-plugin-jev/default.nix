{
  lib,
  buildNpmPackage,
  importNpmLock,
  nodejs_22,
  runtimeShell,
  writeText,
  inputs,
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
    ".opencode/**"
    ".pi/**"
    "packages/oxlint-plugin-jev/vendor/**"
  ];
  config = {
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
    rules = builtins.listToAttrs (
      map (rule: {
        name = "jev/${rule.id}";
        value = "error";
      }) jevRules
    );
  };
  configTemplate = writeText "oxlint-jev.json" (builtins.toJSON config);
  # These are semantic questions, not the AST rules. Keep whole-file presets
  # behind a second opt-in rather than widening the local question command.
  effectQuestions = [
    "single-use-abstraction"
    "error-as-value"
    "shallow-service"
    "swallow-without-capture"
    "unbounded-retry"
    "network-call-in-transaction"
    "read-then-write-race"
    "unbounded-fanout"
    "decode-after-status"
    "cache-in-method"
  ];
  fowlerQuestions = [
    "mysterious-name"
    "feature-envy"
    "data-clumps"
    "primitive-obsession"
    "middle-man"
    "lazy-element"
    "speculative-generality"
    "temporary-field"
    "insider-trading"
    "data-class"
    "comments"
    "repeated-switches"
  ];
  questions =
    prefix: severity: names:
    builtins.listToAttrs (
      map (name: {
        name = "${prefix}/${name}";
        value = severity;
      }) names
    );
  presetsTemplate = writeText "oxlint-jev-presets.json" (
    builtins.toJSON (
      config
      // {
        jsPlugins = config.jsPlugins ++ [
          {
            name = "anti-slop-effect-jev";
            specifier = "@source@/jev/plugin.ts";
          }
          {
            name = "anti-slop-martinfowler-jev";
            specifier = "@source@/martinfowler/jev-plugin.ts";
          }
        ];
        rules = config.rules // questions "anti-slop-martinfowler-jev" "warn" fowlerQuestions;
        overrides = [
          {
            files = [ "**/packages/callstack-diff/**" ];
            rules = questions "anti-slop-effect-jev" "error" effectQuestions;
          }
          {
            files = [
              "**/*.test.*"
              "**/*.spec.*"
              "**/test/**"
              "**/tests/**"
            ];
            rules = questions "anti-slop-effect-jev" "off" effectQuestions // {
              "anti-slop-effect-jev/test-cannot-fail" = "error";
            };
          }
        ];
      }
    )
  );
in
assert lib.assertMsg (jevVersion == "file:vendor/oxlint-plugin-jev") ''
  Keep Jev on the vendored fork, with its exact commit in vendor/oxlint-plugin-jev/UPSTREAM.md.
'';
assert lib.assertMsg
  (oxlintVersion == manifest.dependencies."@oxlint/plugins" && oxlintVersion == "1.86.0")
  ''
    Keep the CLI and plugin API pinned together at 1.86.0.
  '';
(buildNpmPackage.override { inherit nodejs; }) {
  pname = "oxlint-plugin-jev";
  version = "0.1.3";

  src = lib.fileset.toSource {
    root = ./.;
    fileset = lib.fileset.unions [
      ./package.json
      ./package-lock.json
      ./vendor
    ];
  };

  npmDeps = importNpmLock {
    npmRoot = ./.;
    packageSourceOverrides."node_modules/oxlint-plugin-jev" = ./vendor/oxlint-plugin-jev;
  };
  inherit (importNpmLock) npmConfigHook;
  # Local file dependencies must resolve their transitive imports from this
  # node_modules tree, not from the isolated vendored-source store path.
  npmFlags = [ "--install-links" ];
  dontNpmBuild = true;

  installPhase = ''
    runHook preInstall

    pluginRoot=$out/lib/oxlint-jev
    mkdir -p "$pluginRoot" "$out/bin" "$out/share"
    cp -a node_modules "$pluginRoot/"
    cp package.json "$pluginRoot/"
    cp -R vendor "$pluginRoot/"
    cp ${./plugin.ts} "$pluginRoot/plugin.ts"
    cp ${./rules.json} "$pluginRoot/rules.json"
    cp -R ${inputs.anti-slop-incoming}/src "$pluginRoot/anti-slop"
    chmod u+w "$pluginRoot/anti-slop"
    cp ${inputs.anti-slop-incoming}/LICENSE "$pluginRoot/anti-slop/LICENSE"

    specifier="$pluginRoot/plugin.ts"
    if [ ! -f "$specifier" ]; then
      echo "oxlint-plugin-jev entry missing: $specifier" >&2
      exit 1
    fi

    substitute ${configTemplate} "$out/share/oxlint-jev.json" \
      --replace-fail '@jevSpecifier@' "$specifier"
    substitute ${presetsTemplate} "$out/share/oxlint-jev-presets.json" \
      --replace-fail '@jevSpecifier@' "$specifier" \
      --replace-fail '@source@' "$pluginRoot/anti-slop"

    substitute ${./oxlint-jev.sh} "$out/bin/oxlint-jev" \
      --replace-fail '@runtimeShell@' ${lib.escapeShellArg runtimeShell} \
      --replace-fail '@nodejsBin@' ${lib.escapeShellArg (lib.makeBinPath [ nodejs ])} \
      --replace-fail '@oxlintBin@' "$out/lib/oxlint-jev/node_modules/oxlint/bin/oxlint" \
      --replace-fail '@ignoreArgs@' ${
        lib.escapeShellArg (
          lib.escapeShellArgs (
            lib.concatMap (pattern: [
              "--ignore-pattern"
              pattern
            ]) ignorePatterns
          )
        )
      } \
      --replace-fail '@jevConfig@' "$out/share/oxlint-jev.json" \
      --replace-fail '@presetsConfig@' "$out/share/oxlint-jev-presets.json" \
      --replace-fail '@lintChanged@' "$pluginRoot/anti-slop/jev/lint-changed.ts"
    chmod +x "$out/bin/oxlint-jev"
    cat > "$out/bin/anti-slop-diff" <<EOF
    #!${runtimeShell}
    export PATH=${lib.makeBinPath [ nodejs ]}:\$PATH
    exec node "$pluginRoot/anti-slop/diff-rules/run.ts" "\$@"
    EOF
    chmod +x "$out/bin/anti-slop-diff"

    runHook postInstall
  '';

  doInstallCheck = true;
  nativeCheckInputs = [ nodejs ];
  installCheckPhase = ''
    runHook preInstallCheck
    unset TYPESAFE_API_KEY TYPESAFE_AI_API_KEY TYPESAFE_API_KEY_FILE FACTORY_API_KEY AI_GATEWAY_API_KEY
    mkdir -p fixture/src
    echo 'export function add(left: number, right: number): number { return left + right }' > fixture/src/included.ts
    cd fixture
    files=(src/included.ts)
    for dir in ${lib.escapeShellArgs (map (pattern: lib.removeSuffix "/**" pattern) ignorePatterns)}; do
      mkdir -p "$dir"
      cp src/included.ts "$dir/ignored.ts"
      files+=("$dir/ignored.ts")
    done
    # The config lives outside this working directory, just as it does for users.
    actual=$("$out/bin/oxlint-jev" --all --debug=files "''${files[@]}")
    test "$actual" = src/included.ts
    "$out/bin/oxlint-jev" --all src/included.ts
    "$out/bin/oxlint-jev" --presets --all src/included.ts
    "$out/bin/anti-slop-diff" --help
    runHook postInstallCheck
  '';

  meta = {
    description = "Opt-in Oxlint wrapper that asks TypeSafe Jev plain-English rules";
    homepage = "https://github.com/K-Mistele/oxlint-plugin-jev";
    license = lib.licenses.mit;
    mainProgram = "oxlint-jev";
    platforms = lib.platforms.unix;
  };
}
