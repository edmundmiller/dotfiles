{
  lib,
  buildNpmPackage,
  fetchFromGitHub,
}:

buildNpmPackage rec {
  pname = "codex-acp";
  version = "1.1.7";

  src = fetchFromGitHub {
    owner = "agentclientprotocol";
    repo = "codex-acp";
    rev = "v${version}";
    hash = "sha256-RY1iiajNR3eJI9WYARZnbIHnDl5+gmlPo3GVjJEJ9Zs=";
  };

  npmDepsHash = "sha256-8A9JzBZeeDMS/G54O/GlYwIYdpNjI+B2SjxleWXcx74=";
  npmDepsFetcherVersion = 2;
  npmBuildScript = "build";

  meta = {
    description = "Agent Client Protocol adapter for OpenAI Codex";
    homepage = "https://github.com/agentclientprotocol/codex-acp";
    license = lib.licenses.asl20;
    mainProgram = "codex-acp";
  };
}
