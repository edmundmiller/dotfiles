{
  lib,
  buildNpmPackage,
  fetchFromGitHub,
}:

buildNpmPackage rec {
  pname = "codex-acp";
  version = "1.13.2-preview.6";

  src = fetchFromGitHub {
    owner = "agentclientprotocol";
    repo = "codex-acp";
    rev = "v${version}";
    hash = "sha256-+3uPuT8FgIfqA/2Mhj3T0hWrnSiwzbrtnokUGc36lbU=";
  };

  npmDepsHash = "sha256-TZ+jvXsgqGFdwq7IpzMCtd9faXx6yp6mmyxTE2a/U2E=";
  npmDepsFetcherVersion = 2;
  npmBuildScript = "build";

  meta = {
    description = "Agent Client Protocol adapter for OpenAI Codex";
    homepage = "https://github.com/agentclientprotocol/codex-acp";
    license = lib.licenses.asl20;
    mainProgram = "codex-acp";
  };
}
