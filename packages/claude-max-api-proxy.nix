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

  # Fix [object Object] bug: OpenAI content can be string OR array of parts.
  # Upstream only handles plain string content. When gateway sends content
  # arrays [{type:"text",text:"..."}], JS stringifies them as "[object Object]".
  postPatch = ''
    # Widen content type to accept arrays
    substituteInPlace src/types/openai.ts \
      --replace-fail \
        'content: string;' \
        'content: string | Array<{ type: string; text?: string }>;'

    # Replace adapter with version that normalizes content arrays
    cp ${./claude-max-api-proxy-patches/openai-to-cli.ts} src/adapter/openai-to-cli.ts
  '';

  # Build TypeScript → dist/
  npmBuildScript = "build";

  meta = with lib; {
    description = "Expose Claude Max/Pro subscription as OpenAI-compatible API";
    homepage = "https://github.com/atalovesyou/claude-max-api-proxy";
    license = licenses.mit;
    mainProgram = "claude-max-api";
  };
}
