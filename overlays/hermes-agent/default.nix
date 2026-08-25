{ inputs }:
final: prev:

let
  patchedHermesAgent = prev.llm-agents."hermes-agent".overrideAttrs (old: {
    patches = (old.patches or [ ]) ++ [
      ./patches/0002-normalize-auto-title-inputs.patch
      ./patches/0004-classify-cron-script-failures.patch
    ];
  });

  hermesAgentBuzzPilotBase = prev.llm-agents."hermes-agent".overrideAttrs (old: {
    pname = "hermes-agent-buzz-pilot";
    version = "2026.8.19";
    src = inputs.hermes-agent-buzz-pilot-source;
    patches = (old.patches or [ ]) ++ [
      ./patches/0003-report-external-cron-executor.patch
      (inputs.agents-workspace-buzz-typing + /patches/hermes-agent/0001-buzz-01-thread-routing.patch)
      (inputs.agents-workspace-buzz-typing + /patches/hermes-agent/0001-buzz-02-channel-activation.patch)
      (inputs.agents-workspace-buzz-typing + /patches/hermes-agent/0001-buzz-03-working-reaction.patch)
      (inputs.agents-workspace-buzz-typing + /patches/hermes-agent/0001-buzz-04-reconnect-handoff.patch)
      (inputs.agents-workspace-buzz-typing + /patches/hermes-agent/0001-buzz-05-native-typing.patch)
      (inputs.agents-workspace + /patches/hermes-agent/0002-bounded-smart-model-routing.patch)
    ];
    postInstall = (old.postInstall or "") + ''
      chmod -R u+w $out/share/hermes
      rm -rf $out/share/hermes/skills $out/share/hermes/optional-skills $out/share/hermes/plugins
      cp -r skills optional-skills plugins $out/share/hermes/
    '';
    postInstallCheck = (old.postInstallCheck or "") + ''
      grep -q _should_reply_in_thread $out/share/hermes/plugins/platforms/buzz/adapter.py
      HERMES_SOURCE="$PWD" \
        python3 ${inputs.agents-workspace + /tests/test_hermes_buzz_singuloid_pilot.py}
      HERMES_SOURCE="$PWD" \
        python3 ${inputs.agents-workspace + /tests/test_hermes_smart_model_routing.py}
      HERMES_SOURCE="$PWD" \
        python3 ${../../tests/test_hermes_cron_latest_source.py}
      HERMES_SOURCE="$PWD" \
        python3 ${../../tests/test_hermes_cron_external_executor.py}
    '';
    passthru = (old.passthru or { }) // {
      pilotHermesVersion = "0.20.5";
      pilotRelease = "v2026.8.19";
      pilotSmartModelRouting = true;
    };
  });

  honchoAi = final.python313Packages.buildPythonPackage rec {
    pname = "honcho-ai";
    version = "2.2.0";
    format = "wheel";
    src = final.fetchurl {
      url = "https://files.pythonhosted.org/packages/py3/h/honcho-ai/honcho_ai-${version}-py3-none-any.whl";
      hash = "sha256-MvCYpMi8/kKI8JlN2rC8UqaNyHBp0PLOLIdY7ioXYfI=";
    };
    dependencies = with final.python313Packages; [
      httpx
      pydantic
    ];
    doCheck = false;
  };

  rtkHermes = final.python313Packages.buildPythonPackage rec {
    pname = "rtk-hermes";
    version = "1.2.3";
    pyproject = true;
    src = final.fetchPypi {
      pname = "rtk_hermes";
      inherit version;
      hash = "sha256-tOljjbIXSZIdbuNfkb4AkHtZw3EKjEavq7BCs4/vFK8=";
    };
    build-system = with final.python313Packages; [ setuptools ];
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
            --prefix PYTHONPATH : "${honchoAi}/${final.python313.sitePackages}:${rtkHermes}/${final.python313.sitePackages}"
        done
      '';
      inherit (package) meta;
      passthru = (package.passthru or { }) // {
        inherit rtkHermes;
      };
    };

  hermesAgentWithHoncho = withHermesRuntimeDeps "${patchedHermesAgent.name}-honcho" patchedHermesAgent;
  hermesAgentBuzzPilot = withHermesRuntimeDeps "${hermesAgentBuzzPilotBase.name}-runtime" hermesAgentBuzzPilotBase;
in
{
  llm-agents = (prev.llm-agents or { }) // {
    "hermes-agent" = hermesAgentWithHoncho;
    "hermes-agent-buzz-pilot" = hermesAgentBuzzPilot;
  };
}
