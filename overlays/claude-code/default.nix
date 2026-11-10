final: prev:
let
  # Pin Claude Code independently of the other agents in the shared input.
  version = "2.1.322";
  platformArtifacts = {
    aarch64-darwin = {
      platform = "darwin-arm64";
      hash = "sha256-qdI3lJ24FqC3r9iKmo4d82s6WXow9aQdHAU56xgKNFA=";
    };
    aarch64-linux = {
      platform = "linux-arm64";
      hash = "sha256-8iDKUOpPMiIEP/g8wiShJi4BlumJeswIce+pQjWwwf0=";
    };
    x86_64-linux = {
      platform = "linux-x64";
      hash = "sha256-v7NwOtU4AkIyhFm8Yq2kveiue6V8bh7q25wA4Ih0xHg=";
    };
  };
  fetchClaude = system:
    let
      artifact = platformArtifacts.${system};
    in
    final.fetchurl {
      url = "https://storage.googleapis.com/claude-code-dist-86c565f3-f756-42ad-8dfa-d59b1c096819/claude-code-releases/${version}/${artifact.platform}/claude";
      inherit (artifact) hash;
    };
in
{
  llm-agents = (prev.llm-agents or { }) // {
    claude-code = prev.llm-agents.claude-code.overrideAttrs {
      inherit version;
      src = fetchClaude final.stdenv.hostPlatform.system;
      codesignSources = [ (fetchClaude "aarch64-darwin") ];
    };
  };
}
