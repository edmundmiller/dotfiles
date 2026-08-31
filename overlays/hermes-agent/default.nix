{ inputs }:
final: prev:

let
  agentsWorkspacePatchRoot = inputs.agents-workspace + /patches/hermes-agent;
  canonicalBuzzPatchOrder = builtins.filter (name: name != "") (
    final.lib.splitString "\n" (builtins.readFile (agentsWorkspacePatchRoot + "/buzz-stack-order.txt"))
  );
  canonicalBuzzPatches = map (name: agentsWorkspacePatchRoot + "/${name}") canonicalBuzzPatchOrder;
  auxiliaryHermesPatches = [
    (agentsWorkspacePatchRoot + "/0002-bounded-smart-model-routing.patch")
    (agentsWorkspacePatchRoot + "/0003-kanban-platform-toolsets.patch")
    (agentsWorkspacePatchRoot + "/0004-kanban-fan-in-guidance.patch")
    (agentsWorkspacePatchRoot + "/0005-gateway-profile-identity.patch")
  ];
  dashboardLivenessPatch = agentsWorkspacePatchRoot + "/0006-dashboard-profile-lock-liveness.patch";

  # Hermes ships the Photon sidecar source but intentionally leaves its npm
  # dependencies to the deployment.  Keep the old NUC behavior in the shared
  # package so Photon does not regress when every profile converges here.
  hermesPhotonSidecar = final.buildNpmPackage {
    pname = "hermes-photon-sidecar";
    version = "2026.8.19";
    src = inputs.hermes-agent + /plugins/platforms/photon/sidecar;
    npmDepsHash = "sha256-9gGRsAYGbtG6ase55JsdMZXgcdTpHc9ay9aRKFu1k4I=";
    dontNpmBuild = true;
    installPhase = ''
      mkdir -p $out
      cp -R . $out/
    '';
  };

  sharedHermesAgentBase = prev.llm-agents."hermes-agent".overrideAttrs (old: {
    pname = "hermes-agent";
    version = "2026.8.19";
    src = inputs.hermes-agent;
    # The canonical manifest is the production Buzz order. Auxiliary Hermes
    # behavior patches follow it, and dashboard liveness remains an independent
    # final patch so the two stacks cannot silently drift apart.
    patches =
      (old.patches or [ ])
      ++ canonicalBuzzPatches
      ++ auxiliaryHermesPatches
      ++ [
        dashboardLivenessPatch
      ];
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
      needle = "    # spectrum-ts is pinned exactly in package.json/package-lock.json because" + chr(10)
      replacement = (
          chr(10).join([
              "    if (_SIDECAR_DIR / \"node_modules\").exists():",
              "        print(\"  sidecar deps already installed\")",
              "        return 0",
          ])
          + chr(10) + needle
      )
      if needle not in text:
          raise SystemExit("Photon sidecar install marker not found")
      path.write_text(text.replace(needle, replacement, 1))
      PY
    '';
    postInstallCheck = (old.postInstallCheck or "") + ''
      turn_ledger_site="$out/${final.python3.sitePackages}"
      test -f "$turn_ledger_site/hermes_turn_ledger.py"
      (
        cd "$TMPDIR"
        PYTHONNOUSERSITE=1 \
          PYTHONPATH="$turn_ledger_site" \
          ${final.python3}/bin/python3 - "$turn_ledger_site" <<'PY'
      from pathlib import Path
      import sys

      import hermes_turn_ledger

      site = Path(sys.argv[1])
      expected = (site / "hermes_turn_ledger.py").resolve()
      module = Path(hermes_turn_ledger.__file__).resolve()
      if module != expected:
          raise SystemExit(
              f"turn ledger import mismatch: expected {expected}, got {module}"
          )
      PY
      )
      grep -q _should_reply_in_thread $out/share/hermes/plugins/platforms/buzz/adapter.py
      HERMES_SOURCE="$PWD" \
        python3 ${inputs.agents-workspace + /tests/test_hermes_buzz_singuloid_pilot.py}
      HERMES_SOURCE="$PWD" \
        python3 ${inputs.agents-workspace + /tests/test_hermes_smart_model_routing.py}
      HERMES_SOURCE="$PWD" \
        python3 ${inputs.agents-workspace + /tests/test_hermes_kanban_platform_toolset.py}
      HERMES_SOURCE="$PWD" \
        python3 ${inputs.agents-workspace + /tests/test_hermes_gateway_profile_identity.py}
      HERMES_SOURCE="$PWD" \
        python3 ${inputs.agents-workspace + /tests/test_hermes_turn_evidence.py}
      BUZZ_LIVE_EVIDENCE_SCRIPT=${inputs.agents-workspace + /scripts/buzz-live-evidence.py} \
        python3 ${inputs.agents-workspace + /tests/test_buzz_live_evidence.py}
      HERMES_SOURCE="$PWD" \
        python3 ${../../tests/test_hermes_cron_latest_source.py}
      HERMES_SOURCE="$PWD" \
        python3 ${../../tests/test_hermes_cron_failure_summary.py}
      HERMES_SOURCE="$PWD" \
        python3 ${inputs.agents-workspace + /tests/test_hermes_buzz_thread_isolation.py}
      HERMES_SOURCE="$PWD" \
        python3 ${inputs.agents-workspace + /tests/test_hermes_cron_external_executor.py}
      HERMES_SOURCE="$PWD" \
        python3 ${inputs.agents-workspace + /tests/test_hermes_dashboard_profile_liveness.py}
      test -f $out/share/hermes/plugins/platforms/photon/sidecar/node_modules/.package-lock.json
      grep -Fq 'sidecar deps already installed' $out/share/hermes/plugins/platforms/photon/cli.py
    '';
    passthru = (old.passthru or { }) // {
      hermesVersion = "0.20.5";
      hermesRelease = "v2026.8.19";
      smartModelRouting = true;
    };
  });

  # llm-agents' shared Hermes package is built with final.python3. Keep these
  # injected modules on the same interpreter/site-packages ABI instead of
  # assuming the historical NUC Python 3.12 path.
  hermesPythonPackages = final.python3Packages;

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
            --prefix PYTHONPATH : "${honchoAi}/${final.python3.sitePackages}:${rtkHermes}/${final.python3.sitePackages}"
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
