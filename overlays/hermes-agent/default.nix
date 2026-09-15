{ inputs }:
final: prev:

let
  # Match the released llm-agents dependency update; retain its Rust/Maturin
  # packaging and Python version-metadata hook instead of relaxing Hermes' bound.
  upstreamNemoRelay =
    final.lib.findFirst (package: (package.pname or "") == "nemo-relay")
      (throw "Hermes runtime is missing its nemo-relay dependency")
      prev.llm-agents."hermes-agent".propagatedBuildInputs;
  # llm-agents may pin a different Python build than this host's nixpkgs.
  # withPackages drops modules belonging to another interpreter.
  hermesPython = upstreamNemoRelay.pythonModule;
  nemoRelay = upstreamNemoRelay.overrideAttrs (_: rec {
    version = "0.8.4";
    src = final.fetchFromGitHub {
      owner = "NVIDIA";
      repo = "NeMo-Relay";
      tag = version;
      hash = "sha256-5jGFu+DNb1zlCkejY9IPFXkJH1BbY48aNrQhdKisCyg=";
    };
    cargoDeps = final.rustPlatform.fetchCargoVendor {
      inherit src;
      name = "nemo-relay-${version}";
      hash = "sha256-M8FZngHmCN7fns6yXKInAUCT21T1k2q54VChG7MUzAk=";
    };
  });

  # Hermes ships the Photon sidecar source but intentionally leaves its npm
  # dependencies to the deployment.  Keep the old NUC behavior in the shared
  # package so Photon does not regress when every profile converges here.
  hermesPhotonSidecar = final.buildNpmPackage {
    pname = "hermes-photon-sidecar";
    version = "2026.9.11";
    src = inputs.hermes-agent + /plugins/platforms/photon/sidecar;
    npmDepsHash = "sha256-a9IvcIEG6PbV1rH8qOUW4p68yWy8myGJaBrKMveYOwQ=";
    dontNpmBuild = true;
    installPhase = ''
      mkdir -p $out
      cp -R . $out/
    '';
  };

  firecrawlAnydoc = hermesPython.pkgs.buildPythonPackage rec {
    pname = "firecrawl-anydoc";
    version = "0.2.4";
    pyproject = true;

    src = final.fetchPypi {
      pname = "firecrawl_anydoc";
      inherit version;
      hash = "sha256-PilGAnL+qBzeCP1a8R9rDx/wWRkhTdyTmGf3I2LIMDI=";
    };

    cargoDeps = final.rustPlatform.fetchCargoVendor {
      inherit src;
      name = "firecrawl-anydoc-${version}";
      hash = "sha256-yhW5HSzVrZCms4x36J2NGIn1e5YLIgjuNKXM9EJ9J8c=";
    };

    nativeBuildInputs = with final.rustPlatform; [
      cargoSetupHook
      maturinBuildHook
    ];

    pythonImportsCheck = [ "anydoc" ];
  };

  hermesFrontend = final.buildNpmPackage {
    pname = "hermes-frontend";
    version = "2026.9.11";
    src = inputs.hermes-agent;
    npmDepsHash = "sha256-hJe0Fv8TadHoo64cmA3g3eC0fcSoX2bbb0C00QhOoCo=";
    npmFlags = [
      "--ignore-scripts"
      "--engine-strict=false"
    ];
    env.ELECTRON_SKIP_BINARY_DOWNLOAD = "1";
    buildPhase = ''
      runHook preBuild
      npm run build --workspace ui-tui
      npm run build --workspace web -- --outDir "$TMPDIR/web-dist"
      runHook postBuild
    '';
    installPhase = ''
      runHook preInstall
      mkdir -p $out/lib/hermes-tui $out/share/hermes-web
      cp -r ui-tui/dist ui-tui/package.json $out/lib/hermes-tui/
      cp -r "$TMPDIR/web-dist"/. $out/share/hermes-web/
      runHook postInstall
    '';
  };

  useCurrentFrontend =
    arg:
    if builtins.isString arg && final.lib.hasSuffix "/lib/hermes-tui" arg then
      "${hermesFrontend}/lib/hermes-tui"
    else if builtins.isString arg && final.lib.hasSuffix "/share/hermes-web" arg then
      "${hermesFrontend}/share/hermes-web"
    else
      arg;

  sharedHermesAgentBase = prev.llm-agents."hermes-agent".overrideAttrs (
    old:
    let
      hermesRuntimeDeps =
        map (package: if (package.pname or "") == "nemo-relay" then nemoRelay else package) (
          old.propagatedBuildInputs or [ ]
        )
        ++ [ firecrawlAnydoc ];
      hermesPythonEnv = hermesPython.withPackages (_: hermesRuntimeDeps);
      useCurrentRuntime =
        arg:
        if builtins.isString arg && final.lib.hasSuffix "/bin/python3" arg then
          "${hermesPythonEnv}/bin/python3"
        else
          useCurrentFrontend arg;
    in
    {
      pname = "hermes-agent";
      version = "2026.9.11";
      src = inputs.hermes-agent;
      propagatedBuildInputs = hermesRuntimeDeps;
      doInstallCheck = true;
      # Replace llm-agents' release-specific base patches with the same Nix
      # runtime fixes rebased against this source revision. Custom behavior
      # patches are parked in agents-workspace while Hermes focuses on Cadu.
      patches = [
        ./patches/slash-worker-hermes-python.patch
        ./patches/daemon-pool-python314.patch
      ];
      makeWrapperArgs = map useCurrentRuntime (old.makeWrapperArgs or [ ]);
      postInstall = (old.postInstall or "") + ''
        chmod -R u+w $out/share/hermes
        rm -rf $out/share/hermes/skills $out/share/hermes/optional-skills $out/share/hermes/plugins
        cp -r skills optional-skills plugins $out/share/hermes/

        photon_plugin="$out/share/hermes/plugins/platforms/photon"
        photon_sidecar="$photon_plugin/sidecar"
        rm -rf "$photon_sidecar"
        cp -R ${hermesPhotonSidecar} "$photon_sidecar"
        ${final.python3}/bin/python3 - "$photon_plugin/cli.py" <<'PY'
        from pathlib import Path
        import sys

        path = Path(sys.argv[1])
        text = path.read_text()
        needle = "def _install_sidecar() -> int:" + chr(10)
        replacement = (
            needle + chr(10).join([
                "    if sidecar_deps_installed():",
                "        print(\"  sidecar deps already installed\")",
                "        return 0",
            ])
            + chr(10)
        )
        if needle not in text:
            raise SystemExit("Photon sidecar install marker not found")
        path.write_text(text.replace(needle, replacement, 1))
        PY
      '';
      postInstallCheck = (old.postInstallCheck or "") + ''
        ${hermesPythonEnv}/bin/python3 -c '
        import yaml, cryptography, openai, nemo_relay, anydoc
        from importlib.metadata import version
        assert version("nemo-relay") == "0.8.4"
        '
        (
          cd "$TMPDIR"
          HERMES_HOME="$TMPDIR/hermes-worker-test" \
            PYTHONPATH="$out/${hermesPython.sitePackages}" \
            ${hermesPythonEnv}/bin/python3 -c 'import tui_gateway.slash_worker'
        )
        HERMES_HOME="$TMPDIR/hermes-test" HERMES_SOURCE="$PWD" \
          python3 ${../../tests/test_hermes_native_vault_runtime.py}
        test -f ${hermesFrontend}/lib/hermes-tui/dist/entry.js
        test -f ${hermesFrontend}/share/hermes-web/index.html
        grep -Fq ${hermesFrontend} $out/bin/hermes
        test -f $out/share/hermes/plugins/platforms/photon/sidecar/node_modules/.package-lock.json
        grep -Fq 'sidecar deps already installed' $out/share/hermes/plugins/platforms/photon/cli.py
      '';
      passthru = (old.passthru or { }) // {
        nemo-relay = nemoRelay;
        hermesVersion = "0.21.2";
        hermesRelease = "v2026.9.11";
        smartModelRouting = false;
      };
    }
  );

  # Keep injected modules on the same interpreter as the upstream runtime.
  hermesPythonPackages = hermesPython.pkgs;

  honchoAi = hermesPythonPackages.buildPythonPackage rec {
    pname = "honcho-ai";
    version = "2.2.0";
    format = "wheel";
    src = final.fetchurl {
      url = "https://files.pythonhosted.org/packages/py3/h/honcho-ai/honcho_ai-${version}-py3-none-any.whl";
      hash = "sha256-MvCYpMi8/kKI8JlN2rC8UqaNyHBp0PLOLIdY7ioXYfI=";
    };
    dependencies = with hermesPythonPackages; [
      httpx
      pydantic
    ];
    doCheck = false;
  };

  rtkHermes = hermesPythonPackages.buildPythonPackage rec {
    pname = "rtk-hermes";
    version = "1.2.3";
    pyproject = true;
    src = final.fetchPypi {
      pname = "rtk_hermes";
      inherit version;
      hash = "sha256-tOljjbIXSZIdbuNfkb4AkHtZw3EKjEavq7BCs4/vFK8=";
    };
    build-system = with hermesPythonPackages; [ setuptools ];
  };

  withHermesRuntimeDeps =
    name: package:
    final.symlinkJoin {
      inherit name;
      paths = [ package ];
      nativeBuildInputs = [ final.makeWrapper ];
      postBuild = ''
        for exe in hermes hermes-agent hermes-acp; do
          wrapProgram "$out/bin/$exe" \
            --prefix PYTHONPATH : "${honchoAi}/${hermesPython.sitePackages}:${rtkHermes}/${hermesPython.sitePackages}"
        done
      '';
      inherit (package) meta;
      passthru = (package.passthru or { }) // {
        inherit rtkHermes;
      };
    };

  hermesAgent = withHermesRuntimeDeps "${sharedHermesAgentBase.name}-runtime" sharedHermesAgentBase;
in
{
  llm-agents = (prev.llm-agents or { }) // {
    "hermes-agent" = hermesAgent;
  };
}
