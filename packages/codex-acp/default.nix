{
  lib,
  buildNpmPackage,
  fetchFromGitHub,
}:

buildNpmPackage rec {
  pname = "codex-acp";
  version = "1.8.0";

  src = fetchFromGitHub {
    owner = "agentclientprotocol";
    repo = "codex-acp";
    rev = "v${version}";
    hash = "sha256-dmih+6xA+v8oNy8LayIGG0+4Psfkct06O/ECKWnYP+g=";
  };

  npmDepsHash = "sha256-MkbcRubmjR+hioqT4qv6keIVE+5++gO5tyUv913YzPM=";
  npmDepsFetcherVersion = 2;
  npmBuildScript = "build";

  meta = {
    description = "Agent Client Protocol adapter for OpenAI Codex";
    homepage = "https://github.com/agentclientprotocol/codex-acp";
    license = lib.licenses.asl20;
    mainProgram = "codex-acp";
  };
}
