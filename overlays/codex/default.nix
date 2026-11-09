inputs: final: prev:
let
  # Upgrade Codex independently of the other agents in the shared input.
  source = inputs.llm-agents-edge;
in
{
  llm-agents = (prev.llm-agents or { }) // {
    codex = source.packages.${final.stdenv.hostPlatform.system}.codex;
  };
}
