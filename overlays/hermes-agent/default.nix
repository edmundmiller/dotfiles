final: prev:

let
  patchedHermesAgent = prev.llm-agents."hermes-agent".overrideAttrs (old: {
    patches = (old.patches or [ ]) ++ [
      ./patches/0002-normalize-auto-title-inputs.patch
    ];
  });

  honchoAi = final.python313Packages.buildPythonPackage rec {
    pname = "honcho-ai";
    version = "2.1.2";
    format = "wheel";
    src = final.fetchurl {
      url = "https://files.pythonhosted.org/packages/py3/h/honcho-ai/honcho_ai-${version}-py3-none-any.whl";
      hash = "sha256-oiIg8Bpj9qPB1GJarvChQld7g5gcQty2EXdjGGP7qk8=";
    };
    dependencies = with final.python313Packages; [
      httpx
      pydantic
    ];
    doCheck = false;
  };

  hermesAgentWithHoncho = final.symlinkJoin {
    name = "${patchedHermesAgent.name}-honcho";
    paths = [ patchedHermesAgent ];
    nativeBuildInputs = [ final.makeWrapper ];
    postBuild = ''
      for exe in hermes hermes-agent hermes-acp; do
        wrapProgram "$out/bin/$exe" \
          --prefix PYTHONPATH : "${honchoAi}/${final.python313.sitePackages}"
      done
    '';
    inherit (patchedHermesAgent) meta;
    passthru = patchedHermesAgent.passthru or { };
  };
in
{
  llm-agents = (prev.llm-agents or { }) // {
    "hermes-agent" = hermesAgentWithHoncho;
  };
}
