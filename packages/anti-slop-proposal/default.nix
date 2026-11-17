{
  lib,
  buildNpmPackage,
  importNpmLock,
  inputs,
  nodejs_22,
  runtimeShell,
  writeText,
}:

let
  version = "1.86.0";
  proposal = builtins.fromJSON (builtins.readFile ./oxlint.json);
  baselineRules = builtins.fromJSON (builtins.readFile ../anti-slop/rules.json);
  additionsConfig = writeText "oxlint-additions.json" (
    builtins.toJSON (
      proposal
      // {
        categories = lib.genAttrs [
          "correctness"
          "nursery"
          "pedantic"
          "perf"
          "restriction"
          "style"
          "suspicious"
        ] (_: "off");
        # Keep suppressed rules on their original implementation and policy.
        # Omitting them makes Oxlint reject the untouched suppression file.
        jsPlugins = [
          {
            name = "anti-slop";
            specifier = "@antiSlop@/baseline/index.ts";
          }
          {
            name = "anti-slop-additions";
            specifier = "@antiSlop@/index.ts";
          }
        ]
        ++ builtins.tail proposal.jsPlugins;
        rules =
          baselineRules
          // lib.filterAttrs (name: _: lib.hasPrefix "anti-slop-martinfowler/" name) proposal.rules
          // {
            "oxc/no-accumulating-spread" = "error";
            "anti-slop-additions/no-reduce-accumulator-copy" = "error";
            "anti-slop-additions/no-reprovide-ambient-service" = "error";
          };
        overrides = map (
          override:
          override
          // {
            rules = builtins.removeAttrs override.rules [
              "anti-slop-effect/no-manual-tag-comparison"
              "anti-slop-effect/prefer-effect-match"
            ];
          }
        ) proposal.overrides;
      }
    )
  );
  upstreamPluginVersion =
    (builtins.fromJSON (builtins.readFile (inputs.anti-slop-incoming + /package.json)))
    .dependencies."@oxlint/plugins";
in
assert lib.assertMsg (upstreamPluginVersion == version) ''
  anti-slop expects @oxlint/plugins ${upstreamPluginVersion}; update this package and the pinned oxlint together.
'';
(buildNpmPackage.override { nodejs = nodejs_22; }) {
  pname = "anti-slop-proposal";
  inherit version;

  src = inputs.anti-slop-incoming;

  postPatch = ''
    cp ${./package.json} package.json
    cp ${./package-lock.json} package-lock.json
  '';

  npmDeps = importNpmLock { npmRoot = ./.; };
  inherit (importNpmLock) npmConfigHook;
  dontNpmBuild = true;

  installPhase = ''
    runHook preInstall

    pluginDir=$out/lib/anti-slop
    mkdir -p "$pluginDir"
    cp -r src/. "$pluginDir/"
    cp -r node_modules "$pluginDir/"
    cp LICENSE "$pluginDir/"
    cp -r ${inputs.anti-slop}/src "$pluginDir/baseline"
    chmod u+w "$pluginDir/baseline"
    cp ${inputs.anti-slop}/LICENSE "$pluginDir/baseline/LICENSE"
    mkdir -p "$out/bin" "$out/share"
    substitute ${./oxlint.json} "$out/share/oxlint-proposal.json" \
      --replace-fail '@antiSlop@' "$pluginDir"
    substitute ${additionsConfig} "$out/share/oxlint-additions.json" \
      --replace-fail '@antiSlop@' "$pluginDir"
    for mode in proposal additions; do
    cat > "$out/bin/anti-slop-$mode" <<EOF
    #!${runtimeShell}
    exec "$pluginDir/node_modules/oxlint/bin/oxlint" --threads=1 --disable-nested-config --config "$out/share/oxlint-$mode.json" ${
      lib.escapeShellArgs (
        lib.concatMap (pattern: [
          "--ignore-pattern"
          pattern
        ]) (builtins.fromJSON (builtins.readFile ./oxlint.json)).ignorePatterns
      )
    } "\$@"
    EOF
    chmod +x "$out/bin/anti-slop-$mode"
    done

    runHook postInstall
  '';

  doInstallCheck = true;
  nativeCheckInputs = [ nodejs_22 ];
  installCheckPhase = ''
    runHook preInstallCheck
    mkdir -p fixture/packages/{callstack-diff,unrelated}/src
    echo 'export const isLeft = (value) => value._tag === "Left";' > fixture/packages/callstack-diff/src/probe.ts
    cp fixture/packages/callstack-diff/src/probe.ts fixture/packages/unrelated/src/probe.ts
    mkdir -p fixture/.agents fixture/packages/oxlint-plugin-jev/vendor
    cp fixture/packages/callstack-diff/src/probe.ts fixture/.agents/probe.ts
    cp fixture/packages/callstack-diff/src/probe.ts fixture/packages/oxlint-plugin-jev/vendor/probe.ts
    cd fixture
    files=$("$out/bin/anti-slop-proposal" --debug=files packages/*/src/probe.ts .agents/probe.ts packages/oxlint-plugin-jev/vendor/probe.ts)
    test "$files" = $'packages/callstack-diff/src/probe.ts\npackages/unrelated/src/probe.ts'
    if actual=$("$out/bin/anti-slop-proposal" --format=json packages/*/src/probe.ts); then
      echo "Expected the Effect package probe to fail" >&2
      exit 1
    fi
    printf '%s' "$actual" | node -e '
      const fs = require("node:fs");
      const diagnostics = JSON.parse(fs.readFileSync(0, "utf8")).diagnostics;
      if (diagnostics.length !== 1 ||
          diagnostics[0].code !== "anti-slop-effect(no-manual-tag-comparison)" ||
          diagnostics[0].filename !== "packages/callstack-diff/src/probe.ts") {
        throw new Error(JSON.stringify(diagnostics));
      }
    '
    # A conflicting rule remains proposed, not active in the additive gate.
    "$out/bin/anti-slop-additions" packages/*/src/probe.ts
    echo 'export function accept(value: unknown) { return value; }' > packages/unrelated/src/rejected.ts
    if "$out/bin/anti-slop-additions" packages/unrelated/src/rejected.ts; then
      echo "Expected preserved unknown-parameter policy to reject the probe" >&2
      exit 1
    fi
    echo 'export const copied = values.reduce((acc, value) => Object.assign({}, acc, value), {});' > packages/unrelated/src/copied.ts
    if "$out/bin/anti-slop-additions" packages/unrelated/src/copied.ts; then
      echo "Expected the active accumulator-copy rule to reject the probe" >&2
      exit 1
    fi
    test -f "$out/lib/anti-slop/LICENSE"
    test -f "$out/lib/anti-slop/baseline/LICENSE"
    test -f "$out/lib/anti-slop/vendor/eslint-stylistic/LICENSE"
    test -f "$out/lib/anti-slop/vendor/eslint-stylistic/UPSTREAM.md"
    runHook postInstallCheck
  '';

  meta = {
    description = "Opinionated Oxlint rules that reject low-evidence code patterns";
    homepage = "https://github.com/K-Mistele/anti-slop";
    license = lib.licenses.mit;
    mainProgram = "anti-slop-proposal";
    platforms = lib.platforms.all;
  };
}
