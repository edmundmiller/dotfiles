{
  lib,
  buildNpmPackage,
  fetchFromGitHub,
}:

buildNpmPackage rec {
  pname = "codex-acp";
  version = "1.5.0";

  src = fetchFromGitHub {
    owner = "agentclientprotocol";
    repo = "codex-acp";
    rev = "v${version}";
    hash = "sha256-klETNQ+/FjH7XqfcZqOKgfLTbWkPnPMTbqUmVCS5g8A=";
  };

  npmDepsHash = "sha256-S05Z3m/Itb/emskOcP0U4FVMCMdha2oZSHzjX2/n4io=";
  npmDepsFetcherVersion = 2;
  npmBuildScript = "build";

  meta = {
    description = "Agent Client Protocol adapter for OpenAI Codex";
    homepage = "https://github.com/agentclientprotocol/codex-acp";
    license = lib.licenses.asl20;
    mainProgram = "codex-acp";
  };
}
