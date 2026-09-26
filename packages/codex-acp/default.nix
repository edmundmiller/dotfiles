{
  lib,
  buildNpmPackage,
  fetchFromGitHub,
}:

buildNpmPackage rec {
  pname = "codex-acp";
  version = "1.13.1";

  src = fetchFromGitHub {
    owner = "agentclientprotocol";
    repo = "codex-acp";
    rev = "v${version}";
    hash = "sha256-lVsj8RqE8XwCblOBSk3B4Nckx4h1o1BHMRrmpkhrIEw=";
  };

  npmDepsHash = "sha256-jRUBSflIdDe+OF1jcmrtnJVIzCMi9oUXdGo5rZx2uKE=";
  npmDepsFetcherVersion = 2;
  npmBuildScript = "build";

  meta = {
    description = "Agent Client Protocol adapter for OpenAI Codex";
    homepage = "https://github.com/agentclientprotocol/codex-acp";
    license = lib.licenses.asl20;
    mainProgram = "codex-acp";
  };
}
