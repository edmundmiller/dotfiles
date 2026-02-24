{
  lib,
  buildNpmPackage,
  fetchFromGitHub,
}:

buildNpmPackage {
  pname = "claude-max-api-proxy";
  version = "1.0.0";

  src = fetchFromGitHub {
    owner = "atalovesyou";
    repo = "claude-max-api-proxy";
    rev = "eae54779fc21a8b3224c192c14e6b63490fd56d8";
    hash = "sha256-ypzeNoVIGTWhWng7vHWTBgL4/DTzBFX+4ljJ+dDipyA=";
  };

  npmDepsHash = "sha256-qS3YN6mwyMINyLRqD4ocEwhOoBAcfkjN79QVy+x5s2E=";

  # Build TypeScript → dist/
  npmBuildScript = "build";

  meta = with lib; {
    description = "Expose Claude Max/Pro subscription as OpenAI-compatible API";
    homepage = "https://github.com/atalovesyou/claude-max-api-proxy";
    license = licenses.mit;
    mainProgram = "claude-max-api";
  };
}
